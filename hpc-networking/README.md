# HPC networking (standalone)

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-hpc-networking/hpc-networking.zip)

**Resource Manager:** the button uses a **standalone zip** (only this stack), published by GitHub Actions ([`package-orm-hpc-networking.yml`](../.github/workflows/package-orm-hpc-networking.yml)). Leave **working directory** **empty** (Terraform files are at the archive root). If the link 404s, run that workflow once on **`main`**/**`master`** (or push a change under `hpc-networking/`). Forks: replace `ncusato/kove-terraform-oci` in the URL with your repo.

Terraform root that only creates **VCN networking**: Internet gateway + NAT gateway, public and private **route tables**, **security lists**, and subnets.

- **Consolidate management and RDMA into one private subnet:** public + **one** private `/24` (NAT for `0.0.0.0/0`).
- **Separate private subnets for management and RDMA** (default): public + **two** private `/24`s — same **CIDR indexing** as `stig-hardened-builds/rdma-platform` (indices **1** = public, **2** = first private, **3** = second private inside a `/16` VCN). Resource Manager exposes this as a **dropdown**.

## Oracle Cloud Resource Manager (manual zip)

If you are not using the button: zip this directory (include **`schema.yaml`**), upload the zip, and set **working directory** to the zip root (same layout as the CI-built artifact).

After apply, use job **Outputs** — especially **`deployment_network_summary`** and **`network_cidrs_map`** — to see **CIDRs and OCIDs** together.

## CLI

```bash
cd hpc-networking
cp terraform.tfvars.example terraform.tfvars
# edit tfvars
terraform init
terraform apply
```

`private_subnet_layout` must be the **full phrase** exactly as in `variables.tf` / `terraform.tfvars.example` (not the legacy values `one` / `two`). No compute, SSH keys, or images are required.
