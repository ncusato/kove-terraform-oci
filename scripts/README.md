# `scripts/` (Terraform / cloud-init)

Templates and small helpers used by **Terraform** and **cloud-init** live here (`*.tpl`, BM IMDS bootstrap, etc.).

## Consumed by Terraform

| Artifact | Used by |
|----------|---------|
| **`bm_imds_ssh_bootstrap.sh`** | Repo **root** `main.tf` (BM `user_data`). **`stig-hardened-builds/rdma-platform`** embeds the same file via `templatefile("${path.module}/../../scripts/bm_imds_ssh_bootstrap.sh", …)` so bare metal gets stack SSH keys on first boot. |
| **`cloud_init_head.yaml.tpl`**, **`head_bootstrap.sh.tpl`**, etc. | Root stack only (head node / Ansible bootstrap). |

Resource Manager and local `terraform apply` both need the **repo root** layout (this `scripts/` directory present next to the stack or reachable from `path.module`), not a zip of a single subfolder alone, unless you copy `scripts/` into that bundle.

The optional **passwordless SSH head → BM** helper and its config example are shipped to the head inside **`playbooks.zip`**:

- **`../playbooks/scripts/setup_bm_passwordless_ssh.sh`**
- **`../playbooks/scripts/kove-bm-bootstrap.conf.example`**

On the head after a successful **Run Ansible from head** bootstrap, those paths are **`/opt/oci-hpc-ansible/scripts/`**.
