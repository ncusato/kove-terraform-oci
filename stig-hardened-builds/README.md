# STIG-hardened builds (Terraform stacks)

Isolated stacks that stay separate from the root **Kove HPC / BM cluster** Terraform at the repo root.

## Deploy to Oracle Cloud (Resource Manager)

Use the **full repository** zip (not a subfolder-only archive). After the Create Stack page loads, set **Working directory** to the path below (inside the one top-level folder GitHub adds to the zip, e.g. `kove-terraform-oci-Kove-Infra-OCI` for the tag zip, or `kove-terraform-oci-master` if you use `master.zip`).

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/tags/Kove-Infra-OCI.zip)

| Stack | Working directory (under zip root) |
|--------|-------------------------------------|
| **RDMA platform** | `…/stig-hardened-builds/rdma-platform` |
| **OKE cluster** | `…/stig-hardened-builds/oke-cluster` |

The button uses the **`Kove-Infra-OCI`** Git tag (same idea as the [root README](../README.md)); move that tag to the commit you want people to deploy. If you need the latest **`master`** instead, create the stack manually with zip URL `https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip` and the same working directory as above.

**Do you need to destroy an older stack?** Usually **no**. A new Resource Manager **Apply** is tied to **that stack’s Terraform state**. Another stack (or CLI apply elsewhere) is a **separate** deployment. You only need **Destroy** on an old stack if you want to **tear down its cloud resources** or you intentionally reuse the **same** stack record and do not want duplicate VCNs/BMs/charges. Two full applies of **different** stacks can coexist; avoid overlapping **VCN CIDRs** if you later **peer** them (defaults: rdma `10.0.0.0/16`, OKE `10.20.0.0/16`).

**RDMA stack:** `rdma-platform` expects **`scripts/bm_imds_ssh_bootstrap.sh`** at repo root (see [`scripts/README.md`](../scripts/README.md)); a full-repo zip satisfies that.

| Stack | Path | Purpose |
|--------|------|---------|
| RDMA / BM platform | `rdma-platform/` | Bastion, management VM, BM.Optimized3 compute cluster |
| OKE | `oke-cluster/` | Kubernetes (OKE) with dedicated VCN, worker node pool |

Each directory is a standalone Terraform root (`terraform init` inside that folder).
