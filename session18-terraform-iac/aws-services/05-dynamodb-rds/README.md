# 05 · DynamoDB & RDS — Database Services

**Student:** Poorav Kumar Gupta · 24bcs10080

---

## Part A: Amazon DynamoDB

### NoSQL
DynamoDB is a fully managed, serverless **NoSQL key-value and document database**. There are no servers, patching or
storage provisioning; it gives single-digit-millisecond latency at any scale and replicates data across 3 AZs.
Unlike SQL databases there is no fixed schema (except the key) and no joins; you design tables around your **access patterns**.

### Tables
- A collection of items (similar to a SQL table, but schemaless apart from the primary key).
- Capacity modes: **On-Demand** (pay per request, auto-scales) or **Provisioned** (set RCU/WCU, with auto scaling).
- Features: Global Tables (multi-region active-active), Streams (change data capture → Lambda), TTL (auto-expire items),
  Point-in-Time Recovery, encryption at rest, transactions, DAX (in-memory cache).

### Items
- A single record (like a row), up to **400 KB**, identified uniquely by its primary key.

### Attributes
- Name–value pairs inside an item (like columns, but each item can have different attributes).
- Types: scalar (`S` string, `N` number, `B` binary, `BOOL`, `NULL`), document (`M` map, `L` list), sets (`SS`, `NS`, `BS`).

```json
{ "UserId": "u#1001", "OrderDate": "2026-10-07", "Total": 499, "Items": ["book", "pen"], "Status": "SHIPPED" }
```

### Partition key
- Required. DynamoDB hashes it to pick the **physical partition** where the item lives.
- If the primary key is only the partition key, it must be **unique** per item.
- Choose a **high-cardinality, evenly accessed** key (e.g. `UserId`), because a "hot" key throttles one partition.

### Sort key
- Optional second part of a **composite primary key** (partition + sort). Items with the same partition key are stored
  together, ordered by sort key.
- Enables range queries: `begins_with`, `between`, `>`, `<`. Example: all orders of a user in October.
- Secondary indexes: **GSI** (different partition/sort key, any time) and **LSI** (same partition key, different sort key, only at table creation).

```bash
aws dynamodb create-table --table-name Orders \
  --attribute-definitions AttributeName=UserId,AttributeType=S AttributeName=OrderDate,AttributeType=S \
  --key-schema AttributeName=UserId,KeyType=HASH AttributeName=OrderDate,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
aws dynamodb query --table-name Orders \
  --key-condition-expression "UserId = :u AND begins_with(OrderDate, :m)" \
  --expression-attribute-values '{":u":{"S":"u#1001"},":m":{"S":"2026-10"}}'
```

```hcl
resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"
  range_key    = "OrderDate"
  attribute { name = "UserId",    type = "S" }
  attribute { name = "OrderDate", type = "S" }
  point_in_time_recovery { enabled = true }
}
```

### DynamoDB use cases
- Session stores, shopping carts, user profiles.
- Gaming leaderboards, IoT telemetry, ad-tech, event/clickstream data.
- Serverless backends (API Gateway + Lambda + DynamoDB).
- Metadata stores and lock tables (historically the Terraform S3-backend lock table).

---

## Part B: Amazon RDS (Relational Database Service)

### Relational database
RDS is a **managed relational (SQL) database**. AWS handles provisioning, OS/DB patching, backups, monitoring and
failover; you manage schema, queries, users and tuning. Data lives in tables with fixed schemas, relationships (foreign
keys), joins and ACID transactions.

### Supported engines
- **Amazon Aurora** (MySQL- and PostgreSQL-compatible; cloud-native storage, up to 15 replicas, Aurora Serverless v2)
- **PostgreSQL**, **MySQL**, **MariaDB**
- **Oracle**, **Microsoft SQL Server**, **IBM Db2**
- (RDS Custom for Oracle/SQL Server when OS-level access is needed)

### DB instances
- The compute + storage running one database engine: instance class (e.g. `db.t4g.micro`, `db.m7g.large`, `db.r7g` for memory-heavy),
  storage (gp3 / io2, storage autoscaling), engine version, parameter groups & option groups.
- Lives in a **DB subnet group** (private subnets in ≥2 AZs).
- Connected to via an **endpoint** DNS name, never via IP.

### Security
- Place in **private subnets**; set `publicly_accessible = false`.
- **Security groups** allow port 5432/3306 only from the app's SG.
- Encryption at rest with **KMS** (must be chosen at creation); TLS in transit (force with `rds.force_ssl`).
- Credentials in **Secrets Manager** with automatic rotation (`manage_master_user_password = true`), or **IAM database authentication**.
- Audit via CloudTrail (API) + engine logs to CloudWatch; Database Activity Streams for Aurora.

### Backups
- **Automated backups**: daily snapshot + transaction logs, retention 1–35 days, enabling **Point-in-Time Restore** to any second within retention.
- **Manual snapshots**: kept until you delete them; can be copied cross-region/cross-account.
- AWS Backup for centralized policies. A restore always creates a **new** DB instance.

### Multi-AZ
- **High availability**: a synchronous **standby** in another AZ. On failure/maintenance, RDS fails over automatically
  (DNS endpoint flips, ~60–120 s). The standby doesn't serve reads.
- **Multi-AZ DB cluster** (MySQL/PostgreSQL): 1 writer + 2 readable standbys, faster failover (~35 s).

### Read replicas
- **Asynchronous** copies used to **scale reads** (reporting, analytics); up to 15 (Aurora) / 15 (MySQL/PG).
- Can be in another region (DR, low-latency reads) and can be **promoted** to standalone DB.
- Replication lag means reads may be slightly stale.

| | Multi-AZ | Read replica |
|---|---|---|
| Goal | availability / failover | read scaling |
| Replication | synchronous | asynchronous |
| Readable | no (instance) / yes (cluster) | yes |
| Cross-region | no | yes |

```hcl
resource "aws_db_instance" "app" {
  identifier                  = "app-db"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  db_name                     = "appdb"
  username                    = "appadmin"
  manage_master_user_password = true          # password in Secrets Manager
  multi_az                    = true
  storage_encrypted           = true
  backup_retention_period     = 7
  db_subnet_group_name        = aws_db_subnet_group.private.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  deletion_protection         = true
}
```

### RDS use cases
- Transactional business apps: e-commerce orders, banking, ERP/CRM.
- Web application backends (Django/Rails/Spring + PostgreSQL/MySQL).
- Lift-and-shift of existing Oracle/SQL Server workloads.
- Reporting via read replicas.

---

## DynamoDB vs RDS: when to choose which
| | DynamoDB | RDS |
|---|---|---|
| Model | NoSQL key-value/document | Relational SQL |
| Schema | flexible (only key fixed) | fixed schema, migrations |
| Queries | by key / index; no joins | arbitrary SQL, joins, aggregations |
| Scaling | automatic, virtually unlimited, horizontal | vertical (instance size) + read replicas |
| Ops | serverless, no instances | managed instances (choose size, maintenance windows) |
| Pricing | per request or provisioned capacity + storage | per instance-hour + storage + IO |
| Best for | known access patterns, massive scale, low latency | complex queries, relationships, transactions, existing SQL apps |
