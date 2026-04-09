# STIG-hardened builds (Terraform stacks)

Isolated stacks that stay separate from the root **Kove HPC / BM cluster** Terraform at the repo root.

## Deploy to Oracle Cloud (Resource Manager)

Each stack has its **own** published zip (GitHub Actions). Use the matching button; **working directory** differs only for **RDMA** (see table). Releases are recreated on push to **`main`**/**`master`** when that stack’s paths change (tags: `deploy-hpc-networking`, `deploy-oke-cluster`, `deploy-rdma-platform`). Forks: edit button URLs to your `github.com/<org>/<repo>`.

| Stack | Deploy | Working directory |
|--------|--------|-------------------|
| **HPC networking** | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-hpc-networking/hpc-networking.zip) | *(empty / zip root)* |
| **OKE cluster** | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-oke-cluster/oke-cluster.zip) | *(empty / zip root)* |
| **RDMA platform** | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-rdma-platform/rdma-platform.zip) | `stig-hardened-builds/rdma-platform` |

Workflow sources: [`.github/workflows/`](../.github/workflows/) (`package-orm-*.yml`). The root [README](../README.md) **Kove Infra** stack still uses its **tagged** full-repo zip, not these per-stack releases.

**VM shape alignment:** **`oke-cluster`** workers use the same **Flex VM** defaults as **`rdma-platform`** bastion and management (**`VM.Standard.E6.Flex`**, 2 OCPU, 16 GB). Bare metal (**`BM.Optimized3.36`**) is only provisioned by **`rdma-platform`**.

**Do you need to destroy an older stack?** Usually **no**. A new Resource Manager **Apply** is tied to **that stack’s Terraform state**. Another stack (or CLI apply elsewhere) is a **separate** deployment. You only need **Destroy** on an old stack if you want to **tear down its cloud resources** or you intentionally reuse the **same** stack record and do not want duplicate VCNs/BMs/charges. Two full applies of **different** stacks can coexist; avoid overlapping **VCN CIDRs** if you later **peer** them (defaults: rdma `10.0.0.0/16`, OKE `10.20.0.0/16`).

**RDMA stack:** Terraform references **`scripts/bm_imds_ssh_bootstrap.sh`** via `path.module` (see [`scripts/README.md`](../scripts/README.md)). The **ORM zip** workflow bundles that script; a **full monorepo** zip still works if you prefer **`master.zip`** + working directory `…/stig-hardened-builds/rdma-platform`.

| Stack | Path | Purpose |
|--------|------|---------|
| RDMA / BM platform | `rdma-platform/` | Bastion, management VM, BM.Optimized3 compute cluster |
| OKE | `oke-cluster/` | Kubernetes (OKE) with dedicated VCN, worker node pool |

Each directory is a standalone Terraform root (`terraform init` inside that folder).
