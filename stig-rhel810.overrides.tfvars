# STIG / custom RHEL image on bare metal only. Head uses default Oracle Linux 8 (empty head_node_image_ocid).
#   terraform apply -var-file=stig-rhel810.overrides.tfvars
# Optional AD for capacity:
# availability_domain = "pILZ:PHX-AD-2"

head_node_image_ocid = ""
bm_node_image_ocid   = "ocid1.image.oc1.phx.aaaaaaaaovxr5zbjsnhh4jiygg3txy4jv263nd4wxxrdghp5ldp3jtp7w2hq"
# head_node_ssh_user comes from terraform.tfvars (opc) when head is Oracle Linux.
