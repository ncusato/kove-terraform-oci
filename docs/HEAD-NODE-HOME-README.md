# Kove stack — quick notes (head node)

This file is copied to the head node’s home directory at first boot. Full documentation is in the Git repository: **README.md**, **FAQ.md**, and **STACK-REFERENCE.md**.

## RDMA authentication on bare metal nodes

Ansible from the head configures RHEL-side RDMA auth on the BMs. To confirm **OCI CN RDMA re-authentication** is in place **on a BM node** (SSH from head as `cloud-user` or your `instance_ssh_user`):

```bash
sudo systemctl status oci-cn-auth-refresh.timer
sudo systemctl list-timers --all | grep oci-cn-auth-refresh
sudo ls -l /usr/local/bin/oci-cn-auth-refresh.sh
```

If the timer or script is missing, fix SSH from head to the BMs, then from the head run:

```bash
cd /opt/oci-hpc-ansible
sudo /usr/local/bin/ansible-playbook -i inventory/hosts configure-rhel-rdma.yml --limit bm
```

Logs (if present): `/var/log/oci-cn-auth-cron.log`

## Related

- **`docs/HEAD-BM-SSH-README.md`** (repo): passwordless SSH from head to BMs  
- **`/var/log/oci-hpc-ansible-bootstrap.log`**: Ansible-from-head first boot  
- **`/opt/oci-hpc-ansible`**: playbooks when **Run Ansible from head** was enabled at first boot  
