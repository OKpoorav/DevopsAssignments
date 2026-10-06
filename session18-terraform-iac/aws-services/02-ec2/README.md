# 02 · EC2 — Elastic Compute Cloud (Compute)

**Student:** Poorav Kumar Gupta · 24bcs10080

## What is EC2?
EC2 provides resizable **virtual servers (instances)** in the AWS cloud. You choose the OS image, CPU/RAM, storage
and network, and pay per second while it runs. It is IaaS: AWS manages the hardware and hypervisor (Nitro), and you manage
the OS, patches and the application.

## AMI (Amazon Machine Image)
- The template for an instance: root volume snapshot (OS + software), architecture (x86_64 / arm64), virtualization
  type, block-device mapping and launch permissions.
- Sources: AWS-provided (Amazon Linux 2023, Ubuntu, Windows), AWS Marketplace, community, or **your own golden AMI**
  (built with Packer / EC2 Image Builder).
- AMIs are **regional**, so the same OS has a different AMI ID in each region. That's why Terraform looks it up with a data source:

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name", values = ["al2023-ami-2023.*-x86_64"] }
}
```

## Instance types
Name format: `family` + `generation` + `attributes` . `size`, e.g. `t3.micro`, `m7g.large`, `c6i.xlarge`.

| Family | Optimised for | Examples |
|---|---|---|
| **T** (burstable) | low baseline CPU with burst credits, dev/test, small web | t3.micro, t4g.small |
| **M** (general purpose) | balanced CPU/RAM | m6i, m7g |
| **C** (compute) | CPU-heavy, batch, gaming, encoding | c6i, c7g |
| **R / X** (memory) | in-memory DBs, caches | r6i, x2idn |
| **I / D** (storage) | high IOPS local NVMe | i4i |
| **P / G / Inf / Trn** (accelerated) | GPU/ML training & inference | p5, g5, inf2 |

Attributes: `g` = Graviton (ARM), `a` = AMD, `i` = Intel, `d` = local NVMe, `n` = enhanced networking.
Pricing models: **On-Demand**, **Savings Plans / Reserved** (1–3 yr commitment, up to ~72% off), **Spot** (spare
capacity, up to ~90% off, can be interrupted), **Dedicated Hosts**.

## Key pairs
- Public/private key pair (RSA or ED25519) used for **SSH** login to Linux (or decrypting the Windows admin password).
- AWS stores only the public key, which is injected into `~/.ssh/authorized_keys` at launch. You keep the `.pem` private key (`chmod 400`).
- Modern alternatives with no keys and no open port 22: **EC2 Instance Connect** and **SSM Session Manager**.

```bash
aws ec2 create-key-pair --key-name poorav-key --key-type ed25519 --query KeyMaterial --output text > poorav-key.pem
ssh -i poorav-key.pem ec2-user@<public-ip>
```

## Security Groups
- **Stateful virtual firewall** at the instance's network interface (ENI).
- **Allow rules only** (no deny); by default inbound is all denied and outbound all allowed.
- Stateful: return traffic for an allowed connection is automatically allowed.
- Sources can be CIDRs or **other security groups** (e.g. "DB SG allows 5432 from App SG").

| Direction | Port | Source | Why |
|---|---|---|---|
| Inbound | 80/443 | 0.0.0.0/0 | public web |
| Inbound | 22 | your-ip/32 only | admin SSH |
| Outbound | all | 0.0.0.0/0 | updates, APIs |

## EBS (Elastic Block Store)
- Network-attached **block storage volumes** for EC2 (like a virtual disk), in one AZ, persisting independently of the instance.
- Types: **gp3** (general SSD, default, IOPS/throughput tunable), io2 (provisioned IOPS, DBs), st1/sc1 (HDD throughput/cold).
- **Snapshots** are incremental backups stored in S3, used to restore/copy volumes across AZs/regions or create AMIs.
- Encryption with KMS (enable "encrypt by default"). `DeleteOnTermination` controls whether the root volume is deleted with the instance.
- Instance store = ephemeral local NVMe that is lost on stop/terminate.

## Public vs private IP
| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| Reachable from | inside VPC (and peered/VPN) | internet | internet |
| Assigned | from subnet CIDR, always | auto at launch if subnet/launch setting enables it | allocated by you, static |
| On stop/start | kept | **changes** | kept |
| Cost | free | charged (~$0.005/h for all public IPv4) | charged |

The instance OS only sees its private IP. The Internet Gateway does 1:1 NAT between public and private IP.

## Instance lifecycle
```
            launch
              │
          [pending] ──► [running] ──stop──► [stopping] ──► [stopped] ──start──► [pending]
                           │  ▲                                  │
                        reboot│                              terminate
                           │  │                                  ▼
                           └──┘        terminate ──► [shutting-down] ──► [terminated]
```
- **running**: billed for compute.
- **stopped**: no compute charge, but EBS volumes are still billed; the public IP is released.
- **hibernate**: RAM saved to EBS for fast resume.
- **terminated**: gone for good (root EBS deleted if DeleteOnTermination). Use *termination protection* for important instances.
- **user_data** runs once at first boot (cloud-init), as used in Session 19 to install nginx.

## Common use cases
- Web/app servers behind an Application Load Balancer with an **Auto Scaling Group**.
- Self-managed databases, CI runners, bastion hosts.
- Kubernetes worker nodes (EKS managed node groups / Karpenter).
- Batch & HPC (Spot fleets), GPU ML training/inference.
- Lift-and-shift of on-prem VMs.

## Handy CLI (read-only)
```bash
aws ec2 describe-instances --filters Name=tag:Owner,Values=poorav-homework
aws ec2 describe-instance-types --instance-types t3.micro --query 'InstanceTypes[].{vCPU:VCpuInfo.DefaultVCpus,MemMiB:MemoryInfo.SizeInMiB}'
aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' --query 'sort_by(Images,&CreationDate)[-1].ImageId'
```
