# Oracle Services Network (OSN) — used for service gateway route on private subnets (oracle-quickstart/oci-hpc pattern).
data "oci_core_services" "oracle_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
