#!/bin/bash
# Cloud-init / user_data script: run on head node first boot.
# Installs Ansible + OCI CLI, discovers BM nodes from instance pool, runs configure-rhel-rdma playbook.
set -e
LOG=/var/log/oci-hpc-ansible-bootstrap.log
exec > >(tee -a "$LOG") 2>&1

INSTANCE_POOL_ID="${instance_pool_id}"
COMPARTMENT_ID="${compartment_id}"
BM_COUNT=${bm_count}
ANSIBLE_DIR="/opt/oci-hpc-ansible"
PLAYBOOK_B64="${playbook_b64}"
RHEL_PREP_B64="${rhel_prep_b64}"
RDMA_AUTH_B64="${rdma_auth_b64}"
EXTRA_VARS_B64="${extra_vars_b64}"

echo "$(date) Bootstrap: installing packages..."
dnf install -y ansible python3-oci-cli jq || yum install -y ansible python3-oci-cli jq || true
if ! command -v oci >/dev/null 2>&1; then
  pip3 install oci-cli 2>/dev/null || true
fi

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
mkdir -p "$ANSIBLE_DIR"/inventory "$ANSIBLE_DIR"/roles/rhel_prep/tasks "$ANSIBLE_DIR"/roles/rdma_auth/tasks
HEAD_IP=$(hostname -I | awk '{print $1}')
echo "[head]
head-node ansible_host=$HEAD_IP ansible_user=opc

[bm]" > "$ANSIBLE_DIR/inventory/hosts"

i=1
for inst_id in $(oci compute-management instance-pool list-instances --instance-pool-id "$INSTANCE_POOL_ID" --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].instanceId' --raw-output 2>/dev/null); do
  PRIV_IP=$(oci compute instance list-vnics --instance-id "$inst_id" --compartment-id "$COMPARTMENT_ID" --all 2>/dev/null | jq -r '.data[] | select(."is-primary" == true or .isPrimary == true) | ."private-ip" // .privateIp' 2>/dev/null | head -1)
  if [ -n "$PRIV_IP" ]; then
    echo "bm-node-$i ansible_host=$PRIV_IP ansible_user=opc" >> "$ANSIBLE_DIR/inventory/hosts"
    i=$((i+1))
  fi
done

echo "[all:children]
head
bm" >> "$ANSIBLE_DIR/inventory/hosts"

echo "$(date) Bootstrap: writing playbook and roles..."
echo "$PLAYBOOK_B64" | base64 -d > "$ANSIBLE_DIR/configure-rhel-rdma.yml"
echo "$RHEL_PREP_B64" | base64 -d > "$ANSIBLE_DIR/roles/rhel_prep/tasks/main.yml"
echo "$RDMA_AUTH_B64" | base64 -d > "$ANSIBLE_DIR/roles/rdma_auth/tasks/main.yml"
echo "$EXTRA_VARS_B64" | base64 -d > "$ANSIBLE_DIR/extra_vars.yml"

echo "$(date) Bootstrap: running Ansible..."
cd "$ANSIBLE_DIR"
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i inventory/hosts configure-rhel-rdma.yml -e @extra_vars.yml || true

echo "$(date) Bootstrap: done."
