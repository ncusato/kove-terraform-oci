# `scripts/` (Terraform / cloud-init)

Templates and small helpers used by **Terraform** and **cloud-init** live here (`*.tpl`, BM IMDS bootstrap, etc.).

The optional **passwordless SSH head → BM** helper and its config example are shipped to the head inside **`playbooks.zip`**:

- **`../playbooks/scripts/setup_bm_passwordless_ssh.sh`**
- **`../playbooks/scripts/kove-bm-bootstrap.conf.example`**

On the head after a successful **Run Ansible from head** bootstrap, those paths are **`/opt/oci-hpc-ansible/scripts/`**.
