# OCI HPC BM Cluster Stack

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip)

A Terraform configuration for provisioning a High-Performance Computing (HPC) cluster on Oracle Cloud Infrastructure (OCI) with Bare Metal nodes.

## Overview

This stack provisions and configures an HPC cluster on OCI consisting of:
- **1 Head Node** (VM.Standard.E6.Flex) for cluster management
- **4 BM.Optimized3.36 nodes** in a private subnet
- **Flexible networking** - create new VCN or use existing
- **Ansible playbooks** for cluster configuration (full HPC stack with Slurm support)

## Features

- **Head Node**: VM.Standard.E6.Flex instance for cluster management and access
- **Bare Metal Nodes**: 4 BM.Optimized3.36 nodes for compute workloads
- **Flexible Networking**: Option to create new VCN or use existing infrastructure
- **Ansible Automation**: Full HPC stack playbooks included (Slurm, LDAP, NFS, etc.)

## Architecture

```
┌─────────────────────────────────────────┐
│              Terraform                   │
│  • VCN & Subnets (optional)             │
│  • Head Node (VM.Standard.E6.Flex)     │
│  • 4x BM.Optimized3.36 nodes           │
│  • Public & Private Subnets             │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         Ansible Automation              │
│  • Full HPC Stack Configuration        │
│  • Slurm (optional)                     │
│  • LDAP (optional)                      │
│  • NFS Storage                          │
│  • RDMA Configuration                   │
└─────────────────────────────────────────┘
```

### Network Configuration
- **Flexible VCN Setup**: Create a new VCN or use an existing one
- **Dual Subnet Architecture**: 
  - Public subnet for head node (with Internet Gateway)
  - Private subnet for BM nodes (with NAT Gateway)
- **Complete Networking**: When creating a new VCN, includes:
  - VCN with DNS label
  - Public and private subnets with security lists
  - Internet Gateway for public access
  - NAT Gateway for outbound internet access from private subnet
  - Route tables for both subnets

### Compute Resources
- **Head Node**: VM.Standard.E6.Flex (1 OCPU, 8GB RAM) for cluster management
- **BM Nodes**: 4x BM.Optimized3.36 nodes for compute workloads
- **Single Image Input**: One RHEL 8.8 image OCID is provided and reused for both BM and head nodes

### Ansible Configuration
- **Full HPC Stack**: Includes playbooks for complete HPC cluster setup
- **Slurm Support**: Optional job scheduler configuration
- **LDAP Support**: Optional directory services
- **NFS Storage**: Shared storage configuration
- **RDMA Roles**: Available roles for RDMA authentication and RHEL preparation

## Prerequisites

1. **OCI Account** with appropriate permissions:
   - Ability to create compute instances
   - Ability to create VCNs and subnets (if creating new VCN)
   - Access to BM.Optimized3.36 shape (may require service limits increase)

2. **Authentication:** This stack is for OCI Resource Manager only. It uses the **resource principal** (no API keys). The user running the stack must have permission to create the resources in the chosen compartment.

3. **Custom Image**:
   - RHEL 8.8 image OCID compatible with `BM.Optimized3.36` and `VM.Standard.E6.Flex`
   - Image must be in the target compartment

4. **SSH Key Pair**:
   - Public key for instance access

## Terraform Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `tenancy_ocid` | String | Tenancy OCID (pre-filled from your session in the Console) |
| `region` | String | Region (pre-filled from your session in the Console) |
| `compartment_ocid` | String | Compartment where resources will be created |
| `ssh_public_key` | String | SSH public key to inject into instances |
| `bm_node_image_ocid` | String | RHEL 8.8 image OCID for BM nodes (also used for head node) |

### Network Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `use_existing_vcn` | Boolean | false | Use existing VCN (true) or create new (false) |
| `existing_vcn_id` | String | "" | Existing VCN OCID (required if `use_existing_vcn = true`) |
| `existing_public_subnet_id` | String | "" | Existing public subnet OCID for head node |
| `existing_private_subnet_id` | String | "" | Existing private subnet OCID for BM nodes |

**Note**: When `use_existing_vcn = true`, you must provide all three existing resource IDs. When `use_existing_vcn = false`, a new VCN will be created with:
- VCN CIDR: 10.0.0.0/16
- Public subnet CIDR: 10.0.1.0/24
- Private subnet CIDR: 10.0.2.0/24

## Deployment Steps

### Option 1: Deploy via OCI Resource Manager (Recommended)

**One-click deploy:** Use the [Deploy to Oracle Cloud](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/ncusato/kove-terraform-oci/archive/refs/heads/master.zip) button at the top of this README. It opens OCI Resource Manager with this repository’s source (GitHub archive of the `master` branch). If your default branch is `main`, change the button link to use `main.zip` instead of `master.zip`.

#### 1. Prepare Stack Archive (manual upload)

Create a zip file containing all Terraform files:

```bash
# On Windows (PowerShell)
Compress-Archive -Path main.tf,variables.tf,outputs.tf,schema.yaml,inventory.tpl,playbooks -DestinationPath oci-hpc-bm-cluster-stack.zip

# On Linux/Mac
zip -r oci-hpc-bm-cluster-stack.zip main.tf variables.tf outputs.tf schema.yaml inventory.tpl playbooks/
```

**Important**: Ensure the zip file contains:
- `main.tf`
- `variables.tf`
- `outputs.tf`
- `schema.yaml`
- `inventory.tpl` (optional, for Ansible)
- `playbooks/` directory (optional, for Ansible)

#### 2. Create Stack in OCI Resource Manager

1. Navigate to **OCI Console** → **Resource Manager** → **Stacks**
2. Click **Create Stack**
3. Select **Upload my Terraform configuration**
4. Upload `oci-hpc-bm-cluster-stack.zip`
5. Click **Next**

#### 3. Configure Stack Variables

**Required Variables** (in the Console):
- **Tenancy OCID** and **Region** are pre-filled from your session; you usually don’t need to change them.
- **Compartment**: Where to create resources (dropdown filtered by tenancy).
- **SSH Public Key**: For instance access.
- **RHEL 8.8 Image**: Image for BM and head node (dropdown filtered by compartment).

**Optional Network Variables**:
- `use_existing_vcn`: Set to `true` to use existing VCN (default: `false`)
- `existing_vcn_id`, `existing_public_subnet_id`, `existing_private_subnet_id`: When using existing VCN

#### 4. Review and Apply

1. Review the configuration
2. Click **Create** to create the stack
3. Click **Plan** to validate the configuration
4. Review the plan output
5. Click **Apply** to deploy the cluster

#### 5. Monitor Deployment

Monitor the job in **Resource Manager** → **Jobs**:
- **Terraform Phase** (~15-30 minutes):
  - Create VCN and networking (if `use_existing_vcn = false`)
  - Provision head node (VM.Standard.E6.Flex)
  - Provision 4 BM.Optimized3.36 nodes
  - Configure networking and security

### Option 2: Deploy with Terraform CLI

This stack is intended for **OCI Resource Manager** only. Deploy via the Console or the Deploy to Oracle Cloud button. The stack uses the resource principal; no API keys are required.

## Post-Deployment

### Accessing Your Cluster

After deployment, you can access the cluster:

1. **Head Node** (via public IP):
   ```bash
   ssh opc@<head_node_public_ip>
   ```
   The public IP is available in Terraform outputs.

2. **BM Nodes** (via private IP, through head node):
   ```bash
   # From head node
   ssh opc@<bm_node_private_ip>
   ```
   Private IPs are available in Terraform outputs.

### Terraform Outputs

After deployment, Terraform provides:
- `created_vcn_id`: VCN OCID (created or existing)
- `head_node_public_ip`: Public IP of the head node
- `bm_node_private_ips`: List of private IPs for BM nodes
- `existing_vcns_in_compartment`: Helper output listing existing VCNs

### Running Ansible Playbooks

The included Ansible playbooks (`playbooks/site.yml`) support full HPC stack configuration. You'll need to:
1. Generate an Ansible inventory from your deployed nodes
2. Configure variables in the playbooks
3. Run the playbooks from the head node or a management machine

**Note**: The current `inventory.tpl` and `site.yml` are configured for a full HPC stack with Slurm, LDAP, and NFS. You may need to customize these for your specific needs.

## File Structure

```
kove-oci-build-2/
├── main.tf                    # Main Terraform configuration
│                              # - Provider configuration
│                              # - VCN and networking resources
│                              # - Head node instance
│                              # - BM node instances
├── variables.tf                # Terraform variable definitions
├── outputs.tf                  # Terraform outputs
├── schema.yaml                 # OCI Resource Manager stack UI schema
├── inventory.tpl               # Ansible inventory template (full HPC stack)
└── playbooks/
    ├── site.yml                # Main Ansible playbook (full HPC stack)
    └── roles/
        ├── rhel_prep/          # RHEL registration and prep
        │   └── tasks/main.yml
        └── rdma_auth/          # RDMA authentication setup
            └── tasks/main.yml
```

## Ansible Roles

The project includes two Ansible roles that can be used independently:

### `rhel_prep` Role

**Purpose**: Prepares RHEL nodes for HPC workloads

**Tasks**:
- Sets hostname pattern (requires `bm_prefix` variable)
- Registers with Red Hat Subscription Manager (idempotent)
- Pins RHEL release to 8.8
- Enables RHEL repositories (BaseOS, AppStream)
- Installs toolchain (python3, policycoreutils-python-utils, environment-modules)
- Installs RDMA libraries and utilities
- Installs OpenMPI
- Configures environment modules in `.bashrc`

**Required Variables**:
- `rhsm_username`: Red Hat Subscription Manager username
- `rhsm_password`: Red Hat Subscription Manager password
- `bm_prefix`: Hostname prefix for BM nodes (e.g., "node-")

### `rdma_auth` Role

**Purpose**: Configures RDMA authentication for OCI cluster networks

**Tasks**:
- Installs NetworkManager cloud setup
- Configures `nm-cloud-setup` for OCI
- Sets SELinux context for RDMA auth
- Installs `oci-cn-auth` RPM
- Performs initial RDMA authentication
- Creates automated re-authentication system (every 105 minutes)
- Performs RDMA connectivity test

**Required Variables**:
- `rdma_interface`: RDMA interface name (e.g., "eth2")
- `rdma_ping_target`: IP address for RDMA ping test
- `oci_cn_auth_rpm_url`: URL or package name for oci-cn-auth RPM

**Note**: These roles are available but not automatically executed by the current `site.yml` playbook, which is configured for a full HPC stack. You can create a custom playbook to use these roles.

## Troubleshooting

### Terraform Errors

**Error: 400 - CannotParseRequest**
- **Cause**: Instance configuration may have incorrect structure
- **Solution**: Ensure `create_vnic_details` is NOT in instance configuration (cluster networks handle VNICs automatically)

**Error: Missing required argument**
- **Cause**: Missing `compartment_id` in data sources
- **Solution**: Verify all required variables are provided

### Ansible Errors

**RHEL Registration Fails**
- **Cause**: Invalid RHSM credentials
- **Solution**: Verify username/password in stack variables

**RDMA Authentication Fails**
- **Cause**: NetworkManager or oci-cn-auth not properly configured
- **Solution**: Check logs: `journalctl -u oci-cn-auth.service`

### Network Issues

**Nodes Can't Communicate**
- **Cause**: Security list rules not configured
- **Solution**: If using existing VCN, ensure security list allows all traffic within VCN CIDR

**No Internet Access**
- **Cause**: NAT Gateway or route table not configured
- **Solution**: If using existing VCN, ensure private subnet has route to NAT Gateway

## Customization

### Changing Node Count

Edit the `count` parameter in `main.tf` for the `oci_core_instance.bm_nodes` resource (currently set to 4).

### Using Different BM Shape

Modify the `shape` parameter in `main.tf` for the `oci_core_instance.bm_nodes` resource. Supported shapes:
- `BM.Optimized3.36` (current)
- Other BM shapes as available in your region

## Limitations

- **Fixed Node Count**: Currently hardcoded to 4 BM nodes. Edit `main.tf` to change.
- **Fixed Head Node Shape**: Head node is VM.Standard.E6.Flex with 1 OCPU/8GB RAM. Edit `main.tf` to change.
- **Ansible Playbooks**: The included playbooks are for a full HPC stack and may require customization for your needs.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review OCI Resource Manager job logs (if using Resource Manager)
3. Check the stack job logs in Resource Manager
4. Review Terraform state for resource status
5. Check instance console logs in OCI Console

## License

This stack is based on the Oracle Quickstart OCI HPC Stack and follows similar licensing terms.

## References

- [OCI HPC Documentation](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/hpc-cluster-network.htm)
- [OCI Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm)
- [RDMA on OCI](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/hpc-rdma.htm)
