# RHEL 8.8 Image Builder blueprint (OCI BM)

**File:** [`rhel88-bm-native.toml`](rhel88-bm-native.toml) — minimal **UEFI**, **serial console**, **iSCSI/NVMe** boot helpers, **MLX5 RDMA** userspace stack. No baked-in SSH keys (OCI adds keys via `ssh_authorized_keys` on launch).

## Prerequisites

- A machine with **RHEL Image Builder** (subscription) or **Red Hat build pipeline** that accepts this blueprint format (`composer-cli` / `osbuild-composer`).
- `distro = "rhel-88"` must match an available **distro name** in your environment (adjust if your builder uses `rhel-8` or another slug).

## Build (example with `composer-cli`)

On a registered RHEL 8.x host with Image Builder installed:

```bash
sudo composer-cli blueprints push rhel88-bm-native.toml
sudo composer-cli blueprints depsolve rhel88-bm-native
sudo composer-cli compose start rhel88-bm-native qcow2
# wait for FINISHED
sudo composer-cli compose status
sudo composer-cli compose image <UUID>   # downloads artifact
```

Use **`qcow2`** (or the image type your OCI import flow supports; confirm in [Oracle custom image import docs](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/importingcustomimage.htm)).

## Import to OCI

1. Upload the artifact to **Object Storage**.
2. **Compute → Images → Import image** from that object.
3. Copy the image **OCID** into the stack variable **`bm_node_image_ocid`**.

Longer walkthrough (portal signup, bucket, etc.): [RHEL 8.8 OCI import](../RHEL-8-8-OCI-IMPORT.md).

## Extending the minimal blueprint

Add packages only if you need them, for example:

| Need | Add package(s) |
|------|----------------|
| Host firewall | `firewalld` |
| RDMA benchmarks | `perftest` |
| IB diagnostics | `infiniband-diags`, `libibverbs-utils` |
| Link info | `ethtool` |
