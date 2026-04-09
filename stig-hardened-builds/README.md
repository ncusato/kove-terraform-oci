# STIG-hardened builds (Terraform stacks)

Isolated stacks that stay separate from the root **Kove HPC / BM cluster** Terraform at the repo root.

## Deploy to Oracle Cloud (Resource Manager)

Use the **full repository** zip from **`master`** (button below). GitHub unpacks it as a single top-level folder, typically **`kove-terraform-oci-master`**. Set **Working directory** to one of the paths in the table (full path from zip root).

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip)

| Stack | Working directory |
|--------|-------------------|
| **RDMA platform** | `kove-terraform-oci-master/stig-hardened-builds/rdma-platform` |
| **OKE cluster** | `kove-terraform-oci-master/stig-hardened-builds/oke-cluster` |

The root [README](../README.md) HPC stack may still use a **tagged** zip; these STIG-hardened buttons track **`master`** only.

**VM shape alignment:** **`oke-cluster`** workers use the same **Flex VM** defaults as **`rdma-platform`** bastion and management (**`VM.Standard.E6.Flex`**, 2 OCPU, 16 GB). Bare metal (**`BM.Optimized3.36`**) is only provisioned by **`rdma-platform`**.

**Do you need to destroy an older stack?** Usually **no**. A new Resource Manager **Apply** is tied to **that stack’s Terraform state**. Another stack (or CLI apply elsewhere) is a **separate** deployment. You only need **Destroy** on an old stack if you want to **tear down its cloud resources** or you intentionally reuse the **same** stack record and do not want duplicate VCNs/BMs/charges. Two full applies of **different** stacks can coexist; avoid overlapping **VCN CIDRs** if you later **peer** them (defaults: rdma `10.0.0.0/16`, OKE `10.20.0.0/16`).

**RDMA stack:** `rdma-platform` expects **`scripts/bm_imds_ssh_bootstrap.sh`** at repo root (see [`scripts/README.md`](../scripts/README.md)); a full-repo zip satisfies that.

| Stack | Path | Purpose |
|--------|------|---------|
| RDMA / BM platform | `rdma-platform/` | Bastion, management VM, BM.Optimized3 compute cluster |
| OKE | `oke-cluster/` | Kubernetes (OKE) with dedicated VCN, worker node pool |

Each directory is a standalone Terraform root (`terraform init` inside that folder).
