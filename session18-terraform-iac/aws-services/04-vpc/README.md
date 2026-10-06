# 04 · VPC — Virtual Private Cloud (Networking)

**Student:** Poorav Kumar Gupta · 24bcs10080

## What is VPC?
A VPC is your own **logically isolated virtual network** inside an AWS region. You choose the IP range, carve it into
subnets across Availability Zones, and control routing, internet access and firewalls. Every EC2 instance, RDS DB,
EKS node, Lambda-in-VPC etc. lives in a VPC. Each region has a *default VPC* for quick starts; real projects create custom ones (as in Session 19).

```
Region us-east-1
└── VPC 10.20.0.0/16
    ├── AZ us-east-1a
    │   ├── Public subnet  10.20.1.0/24   (route 0.0.0.0/0 → IGW)
    │   └── Private subnet 10.20.11.0/24  (route 0.0.0.0/0 → NAT GW)
    ├── AZ us-east-1b
    │   ├── Public subnet  10.20.2.0/24
    │   └── Private subnet 10.20.12.0/24
    ├── Internet Gateway
    └── NAT Gateway (in a public subnet, with an Elastic IP)
```

## CIDR (Classless Inter-Domain Routing)
- Notation `IP/prefix`: the prefix says how many leading bits are the network part.
  - `/16` → 65,536 addresses, `/24` → 256, `/28` → 16.
- VPC size: between **/16 and /28** (IPv4). Use private RFC 1918 ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Plan ranges so they **don't overlap** with other VPCs/on-prem networks you may peer or VPN with.
- AWS reserves **5 IPs in every subnet** (network, VPC router, DNS, future, broadcast), so a /24 gives 251 usable.

## Subnets
- A slice of the VPC CIDR that lives in **exactly one AZ**.
- A subnet is "public" or "private" purely because of its **route table**.
- Spread subnets across ≥2 AZs for high availability.
- `map_public_ip_on_launch` auto-assigns public IPs (typical for public subnets).

## Route tables
- A set of rules `destination CIDR → target` that decide where traffic leaving a subnet goes.
- Every route table has the implicit `local` route (VPC CIDR → local), which lets all subnets talk to each other.
- Each subnet is associated with one route table (otherwise it uses the VPC's main route table).
- Targets: `igw-…`, `nat-…`, VPC peering, Transit Gateway, VPN gateway, VPC endpoints, ENIs.

| Destination | Target | Meaning |
|---|---|---|
| 10.20.0.0/16 | local | intra-VPC |
| 0.0.0.0/0 | igw-xxxx | internet (public subnet) |
| 0.0.0.0/0 | nat-xxxx | outbound-only internet (private subnet) |

## Internet Gateway (IGW)
- Horizontally scaled, highly available VPC component that allows **two-way** communication with the internet.
- One per VPC. Performs 1:1 NAT between an instance's private IP and its public/Elastic IP.
- Needs: IGW attached + route `0.0.0.0/0 → igw` + instance public IP + SG/NACL allowing traffic.

## NAT Gateway
- Lets instances in **private subnets** reach the internet (package updates, external APIs) **without being reachable from the internet**.
- Lives in a public subnet with an Elastic IP; private route tables point `0.0.0.0/0 → nat`.
- Managed and AZ-scoped: put one per AZ for HA. It is billed per hour plus per GB processed, which is a common surprise cost.
  (Cheaper alternatives for AWS-service traffic: **VPC endpoints** for S3/DynamoDB are free.)

## Security Groups
- **Stateful**, instance/ENI-level firewall, **allow rules only**, evaluated as a whole.
- Can reference other SGs as sources (micro-segmentation: web SG → app SG → db SG).

## Network ACLs (NACLs)
- **Stateless** firewall at the **subnet** boundary, so return traffic must be allowed explicitly (ephemeral ports 1024-65535).
- Numbered rules, evaluated in order, lowest first; supports **allow and deny**.
- Default NACL allows everything; custom NACLs deny everything until you add rules.

| | Security Group | Network ACL |
|---|---|---|
| Level | instance (ENI) | subnet |
| State | stateful | stateless |
| Rules | allow only | allow + deny |
| Evaluation | all rules together | in number order, first match |
| Typical use | main access control | coarse subnet guardrail, block bad IPs |

## Public vs private subnet
| | Public subnet | Private subnet |
|---|---|---|
| Default route | `0.0.0.0/0 → IGW` | `0.0.0.0/0 → NAT GW` (or none) |
| Instances get public IPs | yes (usually) | no |
| Reachable from internet | yes (if SG allows) | no |
| Typical resources | ALB, NAT GW, bastion | app servers, DBs, EKS nodes, caches |

Best-practice 3-tier layout: **ALB in public subnets → app in private subnets → DB in isolated private subnets**.

## Related features
VPC Flow Logs (traffic logging), VPC Peering / Transit Gateway (connect VPCs), Site-to-Site VPN / Direct Connect
(on-prem), VPC Endpoints / PrivateLink (private access to AWS services).

## Terraform snippet (from Session 19)
```hcl
resource "aws_vpc" "main"    { cidr_block = "10.20.0.0/16" }
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.20.1.0/24"
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.main.id }
}
```
