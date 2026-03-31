# Merge when testing STIG-hardened RHEL 8.10 (Phoenix example image).
#   terraform plan  -var-file=terraform.tfvars -var-file=stig-rhel810.overrides.tfvars
#   terraform apply -var-file=terraform.tfvars -var-file=stig-rhel810.overrides.tfvars
#
# Set head_node_ssh_user to the login user your image uses (often cloud-user on OCI RHEL).

head_node_image_ocid = "ocid1.image.oc1.phx.aaaaaaaaovxr5zbjsnhh4jiygg3txy4jv263nd4wxxrdghp5ldp3jtp7w2hq"
bm_node_image_ocid   = "ocid1.image.oc1.phx.aaaaaaaaovxr5zbjsnhh4jiygg3txy4jv263nd4wxxrdghp5ldp3jtp7w2hq"
head_node_ssh_user   = "cloud-user"
# rhel_subscription_release defaults to 8.10 in Terraform; set explicitly only if needed.
