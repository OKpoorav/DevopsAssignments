# 03 · S3 — Simple Storage Service (Storage)

**Student:** Poorav Kumar Gupta · 24bcs10080

## What is S3?
S3 is AWS's **object storage** service: store and retrieve any amount of data over HTTPS. It's designed for
**11 nines (99.999999999 %) durability** by storing data redundantly across ≥3 AZs, scales without limit, and you pay
per GB-month stored + requests + data transfer out. It's not a file system or block device: you `PUT`/`GET` whole objects by key.

## Buckets
- A container for objects; the name is **globally unique** across all AWS accounts (3–63 chars, lowercase, DNS-compatible).
  That's why the Session 18 demo appends a random suffix: `poorav-hw-s18-<hex>`.
- Created in **one region** (data stays there unless you replicate).
- Bucket-level settings: versioning, encryption, lifecycle, policies, Block Public Access, logging, replication, CORS, static website hosting, Object Lock.
- New buckets are private by default, with Block Public Access ON and ACLs disabled (Object Ownership = BucketOwnerEnforced).

## Objects
- An object = **key** (full "path" name, e.g. `logs/2026/10/app.log`) + **data** (0 B – 5 TB) + **metadata** + version ID.
- "Folders" are just key prefixes shown by the console.
- Uploads > 100 MB should use **multipart upload** (required > 5 GB).
- Strong read-after-write consistency for all operations.

```bash
aws s3 cp hello.txt s3://my-bucket/docs/hello.txt
aws s3 ls s3://my-bucket/docs/
aws s3 sync ./site s3://my-bucket/site --delete
aws s3 presign s3://my-bucket/docs/hello.txt --expires-in 3600   # temporary share link
```

## Storage classes
| Class | Use | Min duration | Retrieval |
|---|---|---|---|
| **S3 Standard** | frequently accessed | — | ms |
| **S3 Intelligent-Tiering** | unknown/changing access; auto-moves objects | — | ms (archive tiers optional) |
| **Standard-IA** | infrequent, multi-AZ | 30 d | ms, per-GB retrieval fee |
| **One Zone-IA** | infrequent, re-creatable, 1 AZ | 30 d | ms |
| **Glacier Instant Retrieval** | archive accessed ~quarterly | 90 d | ms |
| **Glacier Flexible Retrieval** | archive | 90 d | minutes–hours |
| **Glacier Deep Archive** | long-term compliance | 180 d | ~12–48 h, cheapest |
| **S3 Express One Zone** | ultra-low latency, single AZ | — | single-digit ms |

## Versioning
- Keeps **every version** of an object; overwrites create a new version, deletes add a **delete marker** (recoverable).
- States: Unversioned → Enabled → Suspended (it can never go back to unversioned).
- Protects against accidental deletes/overwrites; required for replication and Object Lock.
- Pair with lifecycle rules to expire noncurrent versions, or costs grow.
- The Session 18 demo enabled it with `aws_s3_bucket_versioning` (`Status = Enabled`).

## Lifecycle policies
Rules (filtered by prefix/tags/size) that automatically **transition** or **expire** objects:
```json
{ "Rules": [{
  "ID": "logs-tiering", "Status": "Enabled", "Filter": { "Prefix": "logs/" },
  "Transitions": [ { "Days": 30, "StorageClass": "STANDARD_IA" },
                   { "Days": 90, "StorageClass": "GLACIER" } ],
  "Expiration": { "Days": 365 },
  "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
  "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 } }] }
```

## Encryption
- **In transit**: HTTPS/TLS (enforce with a bucket policy condition `aws:SecureTransport`).
- **At rest** (all new objects are encrypted by default since 2023):
  - **SSE-S3**: S3-managed keys, AES-256 (used in the demo).
  - **SSE-KMS**: AWS KMS keys, which give audit trail in CloudTrail, key policies and rotation. Use S3 Bucket Keys to cut KMS cost.
  - **DSSE-KMS**: dual-layer encryption for compliance.
  - **SSE-C**: customer-provided keys per request.
  - **Client-side encryption** before upload.

## Bucket policies
Resource-based JSON policy attached to the bucket that controls access for any principal (other accounts, services, public).
```json
{ "Version": "2012-10-17",
  "Statement": [
    { "Sid": "DenyInsecureTransport", "Effect": "Deny", "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } } },
    { "Sid": "AllowCloudFrontRead", "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject", "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": { "StringEquals": { "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EXAMPLE" } } }
  ] }
```
**Block Public Access** (account and bucket level) overrides any policy/ACL that would make data public, so keep it on unless you really need public data.

## Common use cases
- Static website hosting (often S3 + CloudFront).
- Backups, archives & disaster recovery (with cross-region replication).
- Data lakes and analytics (Athena, Glue, EMR, Redshift Spectrum).
- Application assets/user uploads (pre-signed URLs).
- Log storage (CloudTrail, ALB, VPC Flow Logs).
- **Terraform remote state** backend (S3 with native lock file, `use_lockfile = true`).
- CI/CD artifacts and container/ML model storage.
