#cloud-config
# Ensures cloud-init writes and runs the bootstrap script on RHEL/OCI (raw user_data scripts often don't run).
write_files:
  - path: /opt/oci-hpc-bootstrap.sh
    content: ${bootstrap_script_b64}
    encoding: b64
    permissions: '0755'
runcmd:
  - /opt/oci-hpc-bootstrap.sh
