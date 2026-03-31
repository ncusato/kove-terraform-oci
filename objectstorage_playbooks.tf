# When run_ansible_from_head is true and head_ansible_playbooks_url is empty, upload playbooks.zip
# to a bucket with anonymous object read so the head can curl it at boot. This avoids embedding the
# zip in instance user_data (OCI ~32KB combined metadata + cloud-init write_files failures).

data "oci_objectstorage_namespace" "tenancy_namespace" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "ansible_playbooks" {
  count = local.auto_playbooks_oss ? 1 : 0

  compartment_id     = var.compartment_ocid
  namespace          = data.oci_objectstorage_namespace.tenancy_namespace.namespace
  name               = local.ansible_playbooks_bucket_name
  public_access_type = "ObjectRead"
}

resource "oci_objectstorage_object" "ansible_playbooks_zip" {
  count = local.auto_playbooks_oss ? 1 : 0

  bucket       = oci_objectstorage_bucket.ansible_playbooks[0].name
  namespace    = data.oci_objectstorage_namespace.tenancy_namespace.namespace
  object       = "playbooks.zip"
  source       = data.archive_file.playbooks[0].output_path
  content_type = "application/zip"
}
