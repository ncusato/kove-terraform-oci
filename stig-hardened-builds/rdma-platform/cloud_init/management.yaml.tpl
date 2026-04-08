#cloud-config
# Management host in private subnet; reach via bastion (or other path in your VCN).
# SSH keys are supplied via OCI instance metadata (ssh_authorized_keys).
#
# For RHSM or other secrets, either:
# - Set management_cloud_init_template_path to your own template and use ${rhsm_org_id}, ${rhsm_activation_key}, or keys from cloud_init_template_extra_vars, with values only in secrets.auto.tfvars (gitignored), or
# - Replace this file in-repo with a version that only uses ${...} placeholders (never commit real keys).
