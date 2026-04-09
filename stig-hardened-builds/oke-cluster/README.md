# OKE cluster (starter stack)

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/tags/Kove-Infra-OCI.zip)

**Resource Manager:** use the **full repo** zip from the button, then set **Working directory** to `<zip-root>/stig-hardened-builds/oke-cluster` (for the tag zip, `<zip-root>` is usually `kove-terraform-oci-Kove-Infra-OCI`). For `master.zip`, use the same path under `kove-terraform-oci-master/…`.

Terraform root that creates a **dedicated VCN** and an **Oracle Kubernetes Engine (OKE)** cluster with:

- **Flannel** overlay pod networking (`pods_cidr` / `services_cidr` non-overlapping with the VCN)
- **Public** Kubernetes API endpoint subnet (toggle via `public_control_plane_endpoint`)
- **Service load balancer** subnet (public route to Internet)
- **Private worker** subnet (NAT egress)
- One **node pool** of **VM.Standard.E6.Flex** workers (size and shape configurable)

This is intended to sit beside `../rdma-platform` (different VCN CIDR). Integrate with BM workloads later via peering or a shared hub VCN.

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
