# 01 · IAM — Identity & Access Management (Governance)

**Student:** Poorav Kumar Gupta · 24bcs10080

## What is IAM?
IAM is the AWS service that controls **who** (authentication) can do **what** (authorization) on **which** AWS resources.
It's global (not tied to a region) and free. Every AWS API call, whether from the console, CLI, SDK or Terraform, is
signed with credentials and checked against IAM policies before AWS runs it.

```
Principal (user / role / service)  --request-->  IAM policy evaluation  --> Allow / Deny
   "sst-admin wants s3:DeleteBucket on arn:aws:s3:::my-bucket"
```

## Users
- A long-term identity for **one person or application**.
- Credentials: console password (+ MFA) and/or **access keys** (Access Key ID + Secret) for CLI/API.
- A new user has **no permissions** until policies are attached.
- Best practice: humans should sign in through **IAM Identity Center (SSO)** with temporary credentials rather than long-lived IAM users.

```bash
aws iam create-user --user-name dev-alice
aws iam create-login-profile --user-name dev-alice --password '...' --password-reset-required
```

## Groups
- A collection of users. Policies attached to a group apply to every member (e.g. `Developers`, `Admins`, `ReadOnly`).
- Groups can't be nested and aren't principals (you can't name a group in a resource policy).

```bash
aws iam create-group --group-name Developers
aws iam add-user-to-group --group-name Developers --user-name dev-alice
```

## Roles
- An identity with permissions but **no long-term credentials**. Whoever is trusted to *assume* it gets **temporary
  credentials** from STS (`sts:AssumeRole`).
- Two policies: the **trust policy** (who may assume it) and **permission policies** (what it can do).
- Used by EC2 instances (instance profile), Lambda functions, ECS tasks, EKS pods (IRSA / Pod Identity), cross-account access,
  federated users, and CI/CD such as GitHub Actions via OIDC, which needs no stored keys.

```json
{ "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow",
                  "Principal": { "Service": "ec2.amazonaws.com" },
                  "Action": "sts:AssumeRole" }] }
```

## Policies
JSON documents that define permissions. Structure: `Version`, `Statement[]` → `Effect` (Allow/Deny), `Action`,
`Resource`, optional `Condition`, and `Principal` (resource-based policies only).

| Type | Attached to | Example |
|---|---|---|
| AWS managed | identities | `ReadOnlyAccess`, `AmazonS3FullAccess` |
| Customer managed | identities (reusable, versioned) | `InfrastructureAdminNoDelete` |
| Inline | a single identity (1:1) | one-off exceptions |
| Resource-based | a resource | S3 bucket policy, KMS key policy, SQS policy |
| Permissions boundary | user/role | caps the maximum permissions |
| SCP (Organizations) | account / OU | guardrails for whole accounts |
| Session policy | assumed-role session | further restricts a session |

```json
{ "Version": "2012-10-17",
  "Statement": [{
    "Sid": "ReadOneBucket",
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": ["arn:aws:s3:::poorav-hw-s18-*", "arn:aws:s3:::poorav-hw-s18-*/*"],
    "Condition": { "Bool": { "aws:SecureTransport": "true" } }
  }] }
```

## Permissions: how AWS evaluates a request
1. Everything starts **implicitly denied**.
2. All applicable policies are gathered (SCPs, boundaries, identity, resource, session).
3. **An explicit `Deny` anywhere wins.** Nothing can override it.
4. Otherwise, if some policy `Allow`s (and SCP/boundary also allow), the request is allowed.

> Real example from this homework: Terraform could create the S3 bucket but `terraform destroy` got
> `AccessDenied ... with an explicit deny in an identity-based policy: .../InfrastructureAdminNoDelete`.
> The user had admin-like Allow statements, but the explicit Deny on delete actions won (rule 3).

## Least privilege
Grant **only** the actions and resources needed for the task, and nothing more:
- Start from a narrow policy and add permissions as needed rather than starting with `*`.
- Scope `Resource` to specific ARNs, and use `Condition` keys (source IP, MFA, tags, `aws:RequestedRegion`).
- Use **IAM Access Analyzer** to generate policies from CloudTrail activity and to find unused permissions/external access.
- Review regularly using "last accessed" information.

## IAM best practices
- Lock away the **root user**: enable MFA, create no access keys, use it only for the few root-only tasks.
- Enforce **MFA** for all humans.
- Prefer **roles and temporary credentials** (SSO, OIDC federation, instance profiles) over long-lived access keys.
- If access keys are unavoidable, **rotate** them and never commit them to Git (use secret scanning).
- Manage permissions through **groups/roles**, not per-user policies.
- Apply **least privilege**, use permission boundaries and SCPs as guardrails.
- Use a strong **password policy**.
- Enable **CloudTrail** to audit every API call; use Access Analyzer & credential reports.
- Tag resources and use **ABAC** (attribute-based access control) when teams scale.

## Common use cases
| Use case | IAM feature |
|---|---|
| Developers get read-only prod access | Group + `ReadOnlyAccess` |
| EC2 app reads from S3 without keys | Role + instance profile |
| GitHub Actions deploys to AWS without secrets | OIDC identity provider + role with trust on repo |
| Partner account reads a bucket | Cross-account role or bucket policy |
| Prevent anyone deleting prod resources | Explicit Deny policy / SCP (as seen in this account) |
| Company SSO login to many accounts | IAM Identity Center + permission sets |

## Handy CLI (read-only)
```bash
aws sts get-caller-identity           # who am I?
aws iam list-users
aws iam list-attached-user-policies --user-name <user>
aws iam simulate-principal-policy --policy-source-arn <arn> --action-names s3:DeleteBucket
```
