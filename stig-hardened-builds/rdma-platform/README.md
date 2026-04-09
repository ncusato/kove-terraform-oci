# RDMA platform stack

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-rdma-platform/rdma-platform.zip)

**Resource Manager:** standalone zip from GitHub Actions ([`package-orm-rdma-platform.yml`](../../.github/workflows/package-orm-rdma-platform.yml)) — includes this stack **and** `scripts/bm_imds_ssh_bootstrap.sh` at the paths Terraform expects. Set **Working directory** to **`stig-hardened-builds/rdma-platform`**. If the link 404s, run that workflow or push under `stig-hardened-builds/rdma-platform/` (or change `scripts/bm_imds_ssh_bootstrap.sh`). Forks: change the `github.com/...` owner in the button URL.

**VM sizing (bastion / management):** **`VM.Standard.E6.Flex`**, **2 OCPU**, **16 GB** — the same defaults as **`oke-cluster`** worker nodes. Bare metal nodes use **`BM.Optimized3.36`** (`bm_node_shape`).

Terraform stack for an optional **bastion** (public subnet), a **management VM** (private subnet), and a **BM.Optimized3** plane: **one control** plus **N memory nodes** on a compute cluster in an **RDMA-oriented private subnet**. Networking can be **created** (one VCN, three `/24` subnets) or **existing** (you supply three subnet OCIDs).

This lives under `stig-hardened-builds/rdma-platform` so the original cluster stack at the repo root stays unchanged.

## Layout

| Subnet   | CIDR (new VCN)   | Role                                      |
|----------|------------------|-------------------------------------------|
| public   | `10.0.1.0/24`    | Optional bastion (public IP, SSH)         |
| mgmt     | `10.0.2.0/24`    | Management VM (NAT egress)                |
| rdma     | `10.0.3.0/24`    | BM primary VNICs + `oci_core_compute_cluster` |

New VCN CIDR defaults to `10.0.0.0/16` (`vcn_cidr_block`). Adjust `vcn_cidr_block` if it collides with peered networks.

## Prerequisites

- Terraform `>= 1.3`
- OCI provider `>= 5`
- API key or Resource Manager principal configured for the provider
- A **custom image OCID** for bare metal nodes (`bm_node_image_ocid`)
- SSH public key string (`ssh_public_key`)

## Usage

```bash
cd stig-hardened-builds/rdma-platform
terraform init
cp terraform.tfvars.example terraform.tfvars
cp secrets.auto.tfvars.example secrets.auto.tfvars   # RHSM and other sensitive vars; gitignored
# Edit terraform.tfvars and secrets.auto.tfvars
terraform apply
```

Outputs include bastion public IP (if enabled), management private IP, BM private IPs, compute cluster ID, and an `oke_prerequisites` map for a future OKE layer.

## SSH

- **Bastion:** `ssh opc@<bastion_public_ip>` (keys = your key + Terraform ED25519; see sensitive output `cluster_ssh_private_key_openssh` if needed).
- **Management:** from bastion, `ssh opc@<management_private_ip>`.
- **BMs:** from bastion or management, `ssh opc@<bm_private_ip>` or `cloud-user` / `ec2-user` depending on image. With custom RHEL images, keep `bm_imds_ssh_key_bootstrap = true` so `scripts/bm_imds_ssh_bootstrap.sh` (from the repo root) runs on first boot.

## Bare metal bootstrap script path

User data references `../../scripts/bm_imds_ssh_bootstrap.sh` relative to this stack directory. The **standalone ORM zip** repackages that script under `scripts/` so the path still resolves. See [`scripts/README.md`](../../scripts/README.md) for the full monorepo layout.

## Cloud-init and RHSM secrets (management VM)

**Do not** put real `RHSM_ORG_ID` / `RHSM_ACTIVATION_KEY` values in a file you commit to Git.

1. **Template file (no secrets)**  
   Keep your cloud-init as a **Terraform template**: replace placeholders like `<>` with Terraform syntax `${rhsm_org_id}` and `${rhsm_activation_key}` (or add more keys and pass them via `cloud_init_template_extra_vars`).

2. **Where to store the template**  
   - **Outside the repo:** e.g. `C:/Users/ncusato/Downloads/kove-rdma-cloud-init-standalone-runtime.txt` — set  
     `management_cloud_init_template_path = "C:/Users/ncusato/Downloads/kove-rdma-cloud-init-standalone-runtime.txt"`  
     (forward slashes work well on Windows in Terraform.)  
   - **Inside the repo:** only if the file contains **no** real secrets — only `${...}` placeholders.

3. **Where to put the secret values**  
   - **`secrets.auto.tfvars`** in this stack directory (already in root `.gitignore`), or  
   - **Environment variables:** `TF_VAR_rhsm_org_id`, `TF_VAR_rhsm_activation_key`, or  
   - **`terraform.tfvars`** (also gitignored by this repo).

Example `secrets.auto.tfvars`:

```hcl
rhsm_org_id         = "your-org-id"
rhsm_activation_key = "your-activation-key"
```

Terraform marks those variables **sensitive** so they are redacted in normal plan/apply output. They still land in **Terraform state** and in **OCI instance metadata** (`user_data`, base64). Use a remote state backend with encryption; anyone with root on the instance can decode `user_data`. For stricter control, use **OCI Vault** and fetch secrets at boot with instance principal (not covered here).

**Literal `$` in your template:** use `$$` so Terraform does not treat it as interpolation.

## Existing VCN

Set `use_existing_vcn = true` and provide `existing_vcn_id` plus `existing_public_subnet_id`, `existing_management_subnet_id`, and `existing_rdma_subnet_id`. Security lists on those subnets must allow the traffic you need (this stack does not attach new security lists to existing subnets).

## Variables of note

- `memory_node_count` — number of **memory** BMs (default `2`, so **three** BM instances including one control). There is always **one** control BM (`1 + memory_node_count` instances total).
- `enable_bastion` — set `false` if you only need management + BMs and have another jump host.
- `availability_domain` — optional; if empty, the stack prefers the RDMA subnet’s AD, then management, then public, then the first tenancy AD.

OKE is intentionally out of scope here; use `oke_prerequisites` outputs or a separate repo/layer when you add it.
