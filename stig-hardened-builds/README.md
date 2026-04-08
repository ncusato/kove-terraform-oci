# STIG-hardened builds (Terraform stacks)

Isolated stacks that stay separate from the root **Kove HPC / BM cluster** Terraform at the repo root.

| Stack | Path | Purpose |
|--------|------|---------|
| RDMA / BM platform | `rdma-platform/` | Bastion, management VM, BM.Optimized3 compute cluster |
| OKE | `oke-cluster/` | Kubernetes (OKE) with dedicated VCN, worker node pool |

Each directory is a standalone Terraform root (`terraform init` inside that folder).
