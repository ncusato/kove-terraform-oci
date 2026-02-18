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
  ANSIBLE_DIR="/opt/oci-hpc-ansible"
  PAYLOAD_B64="${payload_b64}"
  EXTRA_VARS_B64="${extra_vars_b64}"
  RHSM_USER_B64="${rhsm_username_b64}"
  RHSM_PASS_B64="${rhsm_password_b64}"

  # Register RHEL with subscription manager first so dnf has repos (required for ansible, unzip, etc.)
  if [ -n "$RHSM_USER_B64" ] && [ -n "$RHSM_PASS_B64" ]; then
    RHSM_USER=$(echo "$RHSM_USER_B64" | base64 -d 2>/dev/null)
    RHSM_PASS=$(echo "$RHSM_PASS_B64" | base64 -d 2>/dev/null)
    if [ -n "$RHSM_USER" ] && [ -n "$RHSM_PASS" ]; then
      echo "$(date) Bootstrap: registering with RHSM..."
      subscription-manager register --username "$RHSM_USER" --password "$RHSM_PASS" --auto-attach --force 2>/dev/null || true
      subscription-manager release --set=8.8 2>/dev/null || true
      subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms --enable=rhel-8-for-x86_64-appstream-rpms 2>/dev/null || true
    fi
  fi

  echo "$(date) Bootstrap: installing packages..."
  dnf install -y ansible python3-oci-cli jq unzip || yum install -y ansible python3-oci-cli jq unzip || true
  if ! command -v oci >/dev/null 2>&1; then
    pip3 install oci-cli 2>/dev/null || true
  fi

  echo "$(date) Bootstrap: extracting playbooks (zip)..."
  mkdir -p "$ANSIBLE_DIR"
  echo "$PAYLOAD_B64" | base64 -d > /tmp/playbooks.zip
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q /tmp/playbooks.zip -d "$ANSIBLE_DIR"
  else
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/playbooks.zip','r').extractall('$ANSIBLE_DIR')"
  fi
  rm -f /tmp/playbooks.zip
  echo "$EXTRA_VARS_B64" | base64 -d > "$ANSIBLE_DIR/extra_vars.yml"

  echo "$(date) Bootstrap: waiting for instance pool to have $BM_COUNT instances (timeout 45 min)..."
  for i in $(seq 1 90); do
    N=$(oci compute-management instance-pool list-instances --instance-pool-id "$INSTANCE_POOL_ID" --compartment-id "$COMPARTMENT_ID" --all 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    if [ "$N" -eq "$BM_COUNT" ] 2>/dev/null; then
      echo "$(date) Bootstrap: found $BM_COUNT instances."
      break
    fi
    echo "$(date) Bootstrap: have $N/$BM_COUNT instances, waiting..."
    sleep 30
  done

  echo "$(date) Bootstrap: getting private IPs..."
  mkdir -p "$ANSIBLE_DIR/inventory"
  HEAD_IP=$(hostname -I | awk '{print $1}')
  echo "[head]
head-node ansible_host=$HEAD_IP ansible_user=$SSH_USER

[bm]" > "$ANSIBLE_DIR/inventory/hosts"

  i=1
  for inst_id in $(oci compute-management instance-pool list-instances --instance-pool-id "$INSTANCE_POOL_ID" --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].instanceId' --raw-output 2>/dev/null); do
    PRIV_IP=$(oci compute instance list-vnics --instance-id "$inst_id" --compartment-id "$COMPARTMENT_ID" --all 2>/dev/null | jq -r '.data[] | select(."is-primary" == true or .isPrimary == true) | ."private-ip" // .privateIp' 2>/dev/null | head -1)
    if [ -n "$PRIV_IP" ]; then
      echo "bm-node-$i ansible_host=$PRIV_IP ansible_user=$SSH_USER" >> "$ANSIBLE_DIR/inventory/hosts"
      i=$((i+1))
    fi
  done

  echo "[all:children]
head
bm" >> "$ANSIBLE_DIR/inventory/hosts"

  echo "$(date) Bootstrap: running Ansible..."
  cd "$ANSIBLE_DIR"
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i inventory/hosts configure-rhel-rdma.yml -e @extra_vars.yml || true

  echo "$(date) Bootstrap: done."
}

# Run main logic after delay so instance principal and network are ready. Background so runcmd can exit.
( nohup bash -c "$(declare -f do_bootstrap); sleep 90; do_bootstrap" >> "$LOG" 2>&1 & )
echo "$(date) Bootstrap: scheduled in 90s, log: $LOG"
