# OKE cluster (starter stack)

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/releases/download/deploy-oke-cluster/oke-cluster.zip)

**Resource Manager:** standalone zip from GitHub Actions ([`package-orm-oke-cluster.yml`](../../.github/workflows/package-orm-oke-cluster.yml)). Leave **working directory** **empty**. If the link 404s, run that workflow or push under `stig-hardened-builds/oke-cluster/`. Forks: change the `github.com/...` owner in the button URL.

**Shape parity with `rdma-platform`:** worker nodes use the same **VM** sizing as that stack’s **bastion** and **management** hosts: **`VM.Standard.E6.Flex`**, **2 OCPU**, **16 GB** (`node_pool_shape`, `node_pool_ocpus`, `node_pool_memory_gbs`). Bare metal (**`BM.Optimized3.36`**) is only in `rdma-platform`, not in this OKE pool.

Terraform root that creates an **Oracle Kubernetes Engine (OKE)** cluster and either:

| Mode | `use_existing_vcn` | Subnets in the VCN |
|------|-------------------|---------------------|
| **Dedicated OKE VCN** | `false` | **3** — Kubernetes API, service LB, workers (default `10.20.0.0/16`-style layout). |
| **Shared with RDMA** | `true` | **6 total** — RDMA stack already created **3** (public, mgmt, rdma at `/24` indices 1–3); this stack adds **3 more** (API, LB, workers at indices `oke_vcn_subnet_index_base`…+2, default **4–6**). **Six subnets in one VCN is correct** for this design — you did **not** create a second VCN for OKE. |

Features:

- **Flannel** overlay pod networking (`pods_cidr` / `services_cidr` non-overlapping with the VCN)
- **Public** Kubernetes API endpoint subnet (toggle via `public_control_plane_endpoint`)
- **Service load balancer** subnet (public route to Internet)
- **Private worker** subnet (NAT / private route tables from RDMA or created here)
- One **node pool** (default **VM.Standard.E6.Flex**)

After apply, output **`networking_layout`** summarizes the mode. **`worker_node_image_ocid`** shows which image was selected; if the node pool fails with **400 InvalidParameter (shape/image)** set **`worker_image_id`** explicitly to an OKE-compatible x86 image for your region (Console → **Kubernetes** → **Node pool** create flow lists compatible images).

## Prerequisites

- Terraform `>= 1.3`, OCI provider `>= 5`
- Policies allowing `cluster-family`, `instance-family`, `virtual-network-family`, etc., in the target compartment
- `ssh_public_key` for worker nodes (`opc`)

## Usage

```bash
cd stig-hardened-builds/oke-cluster
terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform apply
```

## kubeconfig

After the cluster is **ACTIVE**, merge credentials (OCI CLI required):

```bash
oci ce cluster create-kubeconfig \
  --cluster-id <cluster_id_from_output> \
  --file $HOME/.kube/config \
  --region <your-region> \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

Use `PRIVATE_ENDPOINT` if you disabled the public control plane and reach the API from inside the VCN.

## Next steps (roadmap)

- Optional **existing VCN** / subnet variables (reuse `oke_prerequisites` from `rdma-platform` outputs)
- **VCN-native pod networking** and **NSGs** instead of broad security lists
- **Bastion** or **operator** access for private endpoints
- **Workload identity**, **addons** (metrics-server, cluster-autoscaler), **STIG-hardened** node images
