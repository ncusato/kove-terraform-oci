# Patch cluster_setup on head (same error = old playbook from zip)

Run these **on the head node** to fix the "cloud-user" error without re-applying the stack:

```bash
# 1) Fix the role to use per-host user (ansible_user first)
sudo sed -i 's/cluster_ssh_user | default(ansible_user)/ansible_user | default(cluster_ssh_user)/' /opt/oci-hpc-ansible/roles/cluster_setup/tasks/main.yml

# 2) Re-run the playbook
cd /opt/oci-hpc-ansible
sudo ansible-playbook -i inventory/hosts configure-rhel-rdma.yml -e @extra_vars.yml
```

If `ansible-playbook` is not in PATH:

```bash
sudo /usr/local/bin/ansible-playbook -i inventory/hosts configure-rhel-rdma.yml -e @extra_vars.yml
```

After a **future** Terraform apply, the baked-in zip will include the fix and this patch won't be needed.
