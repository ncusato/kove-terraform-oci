#cloud-config
# ssh-rsa in OCI metadata is rejected by default on some OpenSSH 9+ / Oracle Linux images.
write_files:
  - path: /etc/ssh/sshd_config.d/98-oci-allow-rsa-userkeys.conf
    content: |
      PubkeyAcceptedAlgorithms +ssh-rsa
      CASignatureAlgorithms +ssh-rsa
    permissions: '0644'
%{ if run_bootstrap ~}
  - path: /opt/oci-hpc-bootstrap.sh
    content: ${bootstrap_script_b64}
    encoding: b64
    permissions: '0755'
%{ endif ~}
runcmd:
  - test -d /etc/ssh/sshd_config.d && (systemctl try-reload-or-restart sshd 2>/dev/null || service sshd reload 2>/dev/null || true)
%{ if run_bootstrap ~}
  - bash /opt/oci-hpc-bootstrap.sh
%{ endif ~}
