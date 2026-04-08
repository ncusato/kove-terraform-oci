# STIG-hardened builds (Terraform stacks)

Isolated stacks that stay separate from the root **Kove HPC / BM cluster** Terraform at the repo root.

## Deploy to Oracle Cloud (Resource Manager)

Use the **full repository** zip (not a subfolder-only archive). After the Create Stack page loads, set **Working directory** to the path below (inside the one top-level folder GitHub adds to the zip, e.g. `kove-terraform-oci-master` or `kove-terraform-oci-Kove-Infra-OCI`).

| Stack | Working directory (under zip root) | Deploy (stable tag) | Deploy (`master`) |
|--------|-------------------------------------|---------------------|-------------------|
| **RDMA platform** | `…/stig-hardened-builds/rdma-platform` | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/tags/Kove-Infra-OCI.zip) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip) |
| **OKE cluster** | `…/stig-hardened-builds/oke-cluster` | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/tags/Kove-Infra-OCI.zip) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip) |

Same **`Kove-Infra-OCI`** tag semantics as the [root README](../README.md): maintainers move the tag to the commit you want customers to deploy. For bleeding edge, use the **`master`** button.

**RDMA stack:** `rdma-platform` expects **`scripts/bm_imds_ssh_bootstrap.sh`** at repo root (see [`scripts/README.md`](../scripts/README.md)); a full-repo zip satisfies that.

| Stack | Path | Purpose |
|--------|------|---------|
| RDMA / BM platform | `rdma-platform/` | Bastion, management VM, BM.Optimized3 compute cluster |
| OKE | `oke-cluster/` | Kubernetes (OKE) with dedicated VCN, worker node pool |

Each directory is a standalone Terraform root (`terraform init` inside that folder).
