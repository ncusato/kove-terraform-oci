#!/bin/bash
# Bootstrap: installs Ansible + OCI CLI, discovers BM nodes, runs configure-rhel-rdma playbook.
# Delivered via cloud-config write_files + runcmd so cloud-init always runs it on RHEL/OCI.
set -e
LOG=/var/log/oci-hpc-ansible-bootstrap.log
mkdir -p /var/log
echo "$(date) Bootstrap: script started (will run main logic in 90s)" | tee -a "$LOG"

do_bootstrap() {
  exec >> "$LOG" 2>&1
  echo "$(date) Bootstrap: starting..."

  INSTANCE_POOL_ID="${instance_pool_id}"
  COMPARTMENT_ID="${compartment_id}"
  BM_COUNT=${bm_count}
  SSH_USER="${instance_ssh_user}"
  HEAD_SSH_USER="${head_node_ssh_user}"
  ANSIBLE_DIR="/opt/oci-hpc-ansible"
  PAYLOAD_B64="${payload_b64}"
  EXTRA_VARS_B64="${extra_vars_b64}"
  RHSM_USER_B64="${rhsm_username_b64}"
  RHSM_PASS_B64="${rhsm_password_b64}"

  # Ensure pip-installed binaries (ansible-playbook, oci) are on PATH when script runs non-interactively
  export PATH="/usr/local/bin:/usr/bin:$PATH"
  # Use instance principal for OCI CLI (no config file; head node must be in a dynamic group with policy)
  export OCI_CLI_AUTH=instance_principal
  # So manual 'oci' from head node also works, create minimal config for HEAD_SSH_USER
  for _u in root "$HEAD_SSH_USER"; do
    [ -z "$_u" ] && continue
    _d="/home/$_u/.oci"
    [ "$_u" = "root" ] && _d="/root/.oci"
    mkdir -p "$_d"
    printf '[DEFAULT]\nauth=instance_principal\n' > "$_d/config"
    chown -R "$_u:$_u" "$_d" 2>/dev/null || true
  done

  # Register with RHSM only when head node is RHEL (skip for Oracle Linux; OL has free repos)
  if grep -q "Red Hat" /etc/redhat-release 2>/dev/null && ! grep -qi "Oracle" /etc/redhat-release 2>/dev/null && [ -n "$RHSM_USER_B64" ] && [ -n "$RHSM_PASS_B64" ]; then
    RHSM_USER=$(echo "$RHSM_USER_B64" | base64 -d 2>/dev/null)
    RHSM_PASS=$(echo "$RHSM_PASS_B64" | base64 -d 2>/dev/null)
    if [ -n "$RHSM_USER" ] && [ -n "$RHSM_PASS" ]; then
      echo "$(date) Bootstrap: registering head node (RHEL) with RHSM..."
      subscription-manager register --username "$RHSM_USER" --password "$RHSM_PASS" --auto-attach --force 2>/dev/null || true
      subscription-manager release --set=8.8 2>/dev/null || true
      subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms --enable=rhel-8-for-x86_64-appstream-rpms 2>/dev/null || true
    fi
  else
    echo "$(date) Bootstrap: head node is not RHEL (or no RHSM vars); skipping RHSM registration (e.g. Oracle Linux)."
  fi

  # Install packages from standard RHEL repos; Ansible/OCI CLI from pip (not in default repos)
  echo "$(date) Bootstrap: installing packages (python3, pip, jq, unzip)..."
  dnf install -y python3 python3-pip jq unzip || yum install -y python3 python3-pip jq unzip || true
  echo "$(date) Bootstrap: installing Ansible and OCI CLI via pip..."
  pip3 install --break-system-packages ansible oci-cli 2>/dev/null || pip3 install ansible oci-cli 2>/dev/null || true

  echo "$(date) Bootstrap: extracting playbooks (zip)..."
  mkdir -p "$ANSIBLE_DIR"
  echo "$PAYLOAD_B64" | base64 -d > /tmp/playbooks.zip
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q /tmp/playbooks.zip -d "$ANSIBLE_DIR"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/playbooks.zip','r').extractall('$ANSIBLE_DIR')"
  else
    echo "$(date) Bootstrap: ERROR: need unzip or python3 to extract playbooks" >&2
    exit 1
  fi
  rm -f /tmp/playbooks.zip
  echo "$EXTRA_VARS_B64" | base64 -d > "$ANSIBLE_DIR/extra_vars.yml"

  echo "$(date) Bootstrap: waiting for instance pool to have $BM_COUNT instances (timeout 45 min)..."
  for i in $(seq 1 90); do
    N=$(oci compute-management instance-pool list-instances --instance-pool-id "$INSTANCE_POOL_ID" --compartment-id "$COMPARTMENT_ID" --all 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    N=$${N:-0}
    if [ "$${N}" -eq "$BM_COUNT" ] 2>/dev/null; then
      echo "$(date) Bootstrap: found $BM_COUNT instances."
      break
    fi
    echo "$(date) Bootstrap: have $${N}/$BM_COUNT instances, waiting..."
    sleep 30
  done

  echo "$(date) Bootstrap: getting private IPs..."
  mkdir -p "$ANSIBLE_DIR/inventory"
  HEAD_IP=$(hostname -I | awk '{print $1}')
  echo "[head]
head-node ansible_host=$HEAD_IP ansible_user=$HEAD_SSH_USER ansible_connection=local

[bm]" > "$ANSIBLE_DIR/inventory/hosts"

  i=1
  for inst_id in $(oci compute-management instance-pool list-instances --instance-pool-id "$INSTANCE_POOL_ID" --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].instanceId' --raw-output 2>/dev/null); do
    PRIV_IP=""
    for _try in 1 2; do
      RAW=$(oci compute instance list-vnics --instance-id "$inst_id" --compartment-id "$COMPARTMENT_ID" --all 2>/dev/null)
      PRIV_IP=$(echo "$RAW" | jq -r '.data[] | select(."is-primary" == true or .isPrimary == true) | ."private-ip" // .privateIp' 2>/dev/null | head -1)
      if [ -z "$PRIV_IP" ] || [ "$PRIV_IP" = "null" ]; then
        PRIV_IP=$(echo "$RAW" | jq -r '.data[0] | ."private-ip" // .privateIp' 2>/dev/null)
      fi
      if [ -n "$PRIV_IP" ] && [ "$PRIV_IP" != "null" ]; then
        break
      fi
      [ "$_try" -eq 1 ] && sleep 15
    done
    if [ -n "$PRIV_IP" ] && [ "$PRIV_IP" != "null" ]; then
      echo "bm-node-$i ansible_host=$PRIV_IP ansible_user=$SSH_USER" >> "$ANSIBLE_DIR/inventory/hosts"
      i=$((i+1))
    else
      echo "$(date) Bootstrap: WARN no private IP for instance $inst_id after retries" >> "$LOG"
    fi
  done
  BM_ADDED=$((i-1))
  echo "$(date) Bootstrap: added $BM_ADDED BM hosts to inventory" >> "$LOG"

  echo "[all:children]
head
bm" >> "$ANSIBLE_DIR/inventory/hosts"

  echo "$(date) Bootstrap: running Ansible..."
  cd "$ANSIBLE_DIR"
  export ANSIBLE_HOST_KEY_CHECKING=False
  ANSIBLE_PLAYBOOK=$(command -v ansible-playbook 2>/dev/null || echo "/usr/local/bin/ansible-playbook")
  $ANSIBLE_PLAYBOOK -i inventory/hosts configure-rhel-rdma.yml -e @extra_vars.yml || true

  echo "$(date) Bootstrap: done."
}

# Run main logic after delay so instance principal and network are ready. Background so runcmd can exit.
( nohup bash -c "$(declare -f do_bootstrap); sleep 90; do_bootstrap" >> "$LOG" 2>&1 & )
echo "$(date) Bootstrap: scheduled in 90s, log: $LOG"
