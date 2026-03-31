# Head Node BM SSH Bootstrap Guide

## If `/opt/oci-hpc-ansible` is missing (bootstrap never ran)

Cloud-init must create `/opt/oci-hpc-bootstrap.sh` and `/opt/oci-hpc-playbooks.zip` (or download the zip from a URL). If **`write_files` failed** in `/var/log/cloud-init-output.log`, those paths will not exist—the instructions below that reference `/opt/oci-hpc-ansible/scripts/...` only apply **after** a successful bootstrap.

**Fix in Terraform (recommended):** Use current stack defaults: playbooks are uploaded to **Object Storage** and the head **curls** them at boot (see `head_ansible_playbooks_url` and `objectstorage_playbooks.tf`). Then **`terraform apply -replace=oci_core_instance.head_node`**.

**Manual finish without re-creating the head:**

1. On your PC (same directory as state): `terraform output -raw cluster_ssh_private_key_openssh` → on the head, install as **`/root/.ssh/id_ed25519`** (mode `600`) so Ansible can reach BMs as `cloud-user`.
2. Zip the repo’s **`playbooks/`** folder (same excludes as Terraform: omit `site.yml`, `inventory/hosts.sample`), copy to the head, then `sudo unzip -o -q playbooks.zip -d /opt/oci-hpc-ansible`.
3. Create **`/opt/oci-hpc-ansible/extra_vars.yml`** (RHSM, `rdma_ping_target`, etc.) and **`inventory/hosts`** from stack outputs, then run  
   `sudo /usr/local/bin/ansible-playbook -i /opt/oci-hpc-ansible/inventory/hosts /opt/oci-hpc-ansible/configure-rhel-rdma.yml -e @/opt/oci-hpc-ansible/extra_vars.yml`  
   (install `ansible` with pip if needed).

After playbooks exist under `/opt/oci-hpc-ansible`, the sections below apply.

---

This guide fixes BM SSH access from the head node when Ansible cannot log in.

## Why your previous command failed

`Load key ... invalid format` means the private key file on head is malformed (usually copy/paste or CRLF issue).

`Permission denied (publickey)` means the BM rejected the offered key for that user.

Recommended flow:
1. Copy the same private key you use to log into the head/bastion to `~/.ssh/head_login_key`.
2. Run the helper script once.
3. Use head `~/.ssh/id_ed25519` for ongoing passwordless SSH to BM nodes.

## 1) Copy the same local key you use to SSH to head

From your **Windows machine** (PowerShell), copy your head/bastion login private key to head as `~/.ssh/head_login_key`.

Replace `C:\\Users\\ncusato\\.ssh\\id_rsa` with your actual local key path if different.

```powershell
$HEAD_IP = "161.153.91.230"
$LOCAL_KEY = "C:\\Users\\ncusato\\.ssh\\id_rsa"

scp -i "$LOCAL_KEY" "$LOCAL_KEY" "opc@$HEAD_IP:~/.ssh/head_login_key"
```

If your local key is ED25519:

```powershell
$LOCAL_KEY = "C:\\Users\\ncusato\\.ssh\\id_ed25519"
scp -i "$LOCAL_KEY" "$LOCAL_KEY" "opc@$HEAD_IP:~/.ssh/head_login_key"
```

## 2) On head, create config + run one script

```bash
cd ~
chmod 600 ~/.ssh/head_login_key
cp /opt/oci-hpc-ansible/scripts/kove-bm-bootstrap.conf.example ~/kove-bm-bootstrap.conf 2>/dev/null || true
# If you keep a repo checkout on the head instead (canonical path in repo: playbooks/scripts/):
cp ~/kove-oci-build-2/playbooks/scripts/kove-bm-bootstrap.conf.example ~/kove-bm-bootstrap.conf 2>/dev/null || true

# Edit ~/kove-bm-bootstrap.conf (BM_IPS, key path, RDMA interface, cron schedule)
vi ~/kove-bm-bootstrap.conf

CONFIG_FILE=~/kove-bm-bootstrap.conf bash /opt/oci-hpc-ansible/scripts/setup_bm_passwordless_ssh.sh || \
CONFIG_FILE=~/kove-bm-bootstrap.conf bash ~/setup_bm_passwordless_ssh.sh
```

If the script is in your repo checkout on the head:

```bash
cd ~/kove-oci-build-2
chmod +x playbooks/scripts/setup_bm_passwordless_ssh.sh
CONFIG_FILE=~/kove-bm-bootstrap.conf ./playbooks/scripts/setup_bm_passwordless_ssh.sh
```

This script will:
- use `~/.ssh/head_login_key` to reach BM nodes,
- append head's `~/.ssh/id_ed25519.pub` to BM `authorized_keys`,
- verify passwordless SSH with `~/.ssh/id_ed25519`,
- update `/etc/hosts` on head and each reachable BM with a managed `# BEGIN KOVE BM HOSTS` block,
- create/update RDMA auth refresh cron on each reachable BM (`/etc/cron.d/oci-cn-auth-refresh` + `/usr/local/bin/oci-cn-auth-refresh.sh`).

## 3) Test simple SSH to a BM

```bash
ssh -i ~/.ssh/id_ed25519 cloud-user@172.16.6.214
```

## Optional overrides

Different BM list:

```bash
BM_IPS="172.16.6.214 172.16.7.211 172.16.5.157 172.16.7.29" ./playbooks/scripts/setup_bm_passwordless_ssh.sh
```

Different bootstrap key path:

```bash
BOOTSTRAP_KEY_PATH=~/.ssh/my_local_key ./playbooks/scripts/setup_bm_passwordless_ssh.sh
```

Disable `/etc/hosts` updates:

```bash
DO_HOSTS_UPDATE=false ./playbooks/scripts/setup_bm_passwordless_ssh.sh
```

Disable RDMA cron setup:

```bash
ENABLE_RDMA_CRON=false ./playbooks/scripts/setup_bm_passwordless_ssh.sh
```

## If still failing

Run verbose once:

```bash
ssh -vvv -o IdentitiesOnly=yes -i ~/.ssh/head_login_key cloud-user@172.16.6.214
```

If key is rejected, the BM does not have the matching public key for that user.
