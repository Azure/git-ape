---
name: aws-naming-research
description: "Research AWS resource naming conventions and constraints for a given service. Use when you need to look up naming rules (length, valid characters, scope), recommended patterns, and uniqueness requirements for AWS resources. Triggers on: AWS naming rules research, resource naming constraints, S3 bucket name validation."
argument-hint: "AWS service or resource type to look up (e.g. 'S3 bucket', 'Lambda function', 'IAM role', 'RDS instance')"
user-invocable: true
last_updated: "2026-04-15"
---

# AWS Naming Research

## Procedure

### 1. Look Up Naming Constraints

For the requested AWS resource type, apply the constraints table below. If the resource is not listed, fetch the official AWS documentation.

**Reference:** [AWS Resource Naming Rules](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)

### 2. Apply Recommended Pattern

Use the recommended naming pattern from the table below and construct a compliant name for the user's deployment.

### 3. Validate the Name

Check:
- Length is within min-max bounds
- Characters used are in the allowed set
- Starts/ends with allowed characters
- Meets uniqueness scope requirement

### 4. Return JSON Summary

```json
{
  "resource": "S3 Bucket",
  "proposed_name": "my-app-data-prod-abc123",
  "valid": true,
  "constraints": {
    "min_length": 3,
    "max_length": 63,
    "allowed_chars": "lowercase letters, numbers, hyphens",
    "start_with": "letter or number",
    "end_with": "letter or number",
    "no_consecutive_hyphens": true,
    "no_ip_format": true,
    "scope": "global",
    "globally_unique": true
  },
  "validation_notes": []
}
```

---

## Naming Constraints Reference

### S3 Buckets

| Constraint | Value |
|-----------|-------|
| **Min length** | 3 |
| **Max length** | 63 |
| **Valid characters** | Lowercase letters (a-z), numbers (0-9), hyphens (-), dots (.) |
| **Must start with** | Letter or number |
| **Must end with** | Letter or number |
| **No consecutive hyphens** | True |
| **No IP format** | Cannot be formatted as IP address (e.g., 192.168.1.1) |
| **Scope** | **Global** — unique across all AWS accounts and regions |
| **Notes** | Dots allowed but not recommended (breaks SSL). Use hyphens instead. |

**Recommended pattern:** `{project}-{purpose}-{env}-{random-suffix}`
**Example:** `myapp-uploads-prod-a7k3m`

---

### Lambda Functions

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 64 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-), underscores (_) |
| **Scope** | **Regional** — unique within an AWS account and region |

**Recommended pattern:** `{project}-{function-purpose}-{env}`
**Example:** `myapp-process-orders-prod`

---

### IAM Roles

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 64 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-), underscores (_), dots (.), at signs (@), equals (=), plus (+), comma (,) |
| **Scope** | **Account** — unique within an AWS account (global to all regions) |

**Recommended pattern:** `{project}-{service}-{purpose}-role-{env}`
**Example:** `myapp-lambda-processor-role-prod`

---

### IAM Policies

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 128 |
| **Valid characters** | Letters, numbers, hyphens, underscores, dots, `+`, `=`, `,`, `@` |
| **Scope** | **Account** |

**Recommended pattern:** `{project}-{resource}-{permissions}-policy`
**Example:** `myapp-dynamodb-read-policy`

---

### EC2 Instances (Name Tag)

| Constraint | Value |
|-----------|-------|
| **Min length** | 0 |
| **Max length** | 256 (tag value limit) |
| **Valid characters** | Any UTF-8 characters |
| **Scope** | **Account + Region** (tag Name is not unique) |

**Recommended pattern:** `{project}-{role}-{env}-{az-or-index}`
**Example:** `myapp-web-prod-1`

---

### EC2 Security Groups

| Constraint | Value |
|-----------|-------|
| **Max name length** | 255 (group name) |
| **Valid characters** | Letters, numbers, spaces, and `_.-:/()#,@[]+=&;{}!$*` |
| **Scope** | **VPC** |

**Recommended pattern:** `{project}-{tier}-{protocol}-sg-{env}`
**Example:** `myapp-web-https-sg-prod`

---

### RDS DB Instance Identifiers

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 63 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-) |
| **Must start with** | Letter |
| **Cannot end with** | Hyphen |
| **No consecutive hyphens** | True |
| **Scope** | **Regional** — unique within an AWS account and region |

**Recommended pattern:** `{project}-{db-purpose}-{env}`
**Example:** `myapp-users-prod`

---

### DynamoDB Tables

| Constraint | Value |
|-----------|-------|
| **Min length** | 3 |
| **Max length** | 255 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-), underscores (_), dots (.) |
| **Scope** | **Regional** — unique within an AWS account and region |

**Recommended pattern:** `{Project}-{Entity}-{Env}` (use PascalCase for DynamoDB)
**Example:** `MyApp-Orders-Prod`

---

### ECS Clusters

| Constraint | Value |
|-----------|-------|
| **Max length** | 255 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{env}-cluster`
**Example:** `myapp-prod-cluster`

---

### ECS Task Definitions (Family Name)

| Constraint | Value |
|-----------|-------|
| **Max length** | 255 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **Scope** | **Regional** — revision number appended automatically |

**Recommended pattern:** `{project}-{service}-task`
**Example:** `myapp-api-task`

---

### EKS Clusters

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 100 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-) |
| **Must start with** | Letter |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{env}-eks`
**Example:** `myapp-prod-eks`

---

### Secrets Manager Secrets

| Constraint | Value |
|-----------|-------|
| **Max length** | 512 |
| **Valid characters** | Any ASCII characters except `/`, `\`, `@`, `#`, or space as first character |
| **Recommended separator** | `/` for hierarchical naming |
| **Scope** | **Regional** |

**Recommended pattern:** `{env}/{project}/{purpose}`
**Example:** `prod/myapp/database-credentials`

---

### CloudFormation Stacks

| Constraint | Value |
|-----------|-------|
| **Min length** | 1 |
| **Max length** | 128 |
| **Valid characters** | Letters (a-z, A-Z), numbers (0-9), hyphens (-) |
| **Must start with** | Letter |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{component}-{env}`
**Example:** `myapp-api-prod`

---

### SNS Topics

| Constraint | Value |
|-----------|-------|
| **Max length** | 256 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **FIFO suffix** | Must end in `.fifo` for FIFO topics |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{event-type}-topic[-{env}]`
**Example:** `myapp-order-events-topic`

---

### SQS Queues

| Constraint | Value |
|-----------|-------|
| **Max length** | 80 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **FIFO suffix** | Must end in `.fifo` for FIFO queues |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{purpose}-queue[-{env}]`
**Example:** `myapp-order-processing-queue`

---

### EventBridge Rules

| Constraint | Value |
|-----------|-------|
| **Max length** | 64 |
| **Valid characters** | Letters, numbers, hyphens, underscores, dots |
| **Scope** | **Regional** — unique within an event bus |

**Recommended pattern:** `{source}-{event-type}-rule`
**Example:** `orders-created-rule`

---

### API Gateway APIs

| Constraint | Value |
|-----------|-------|
| **Max length** | 128 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{version}-api[-{env}]`
**Example:** `myapp-v1-api-prod`

---

### Cognito User Pools

| Constraint | Value |
|-----------|-------|
| **Max length** | 128 |
| **Valid characters** | Letters, numbers, spaces, hyphens, underscores |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{env}-users`
**Example:** `myapp-prod-users`

---

### Step Functions State Machines

| Constraint | Value |
|-----------|-------|
| **Max length** | 80 |
| **Valid characters** | Letters, numbers, hyphens, underscores |
| **Scope** | **Regional** |

**Recommended pattern:** `{project}-{workflow-purpose}-workflow`
**Example:** `myapp-order-processing-workflow`

---

### CloudWatch Log Groups

| Constraint | Value |
|-----------|-------|
| **Max length** | 512 |
| **Valid characters** | Letters, numbers, `_`, `-`, `/`, `.`, `#` |
| **Recommended separator** | `/` for hierarchical grouping |
| **Scope** | **Regional** |

**Recommended pattern:** `/{service}/{project}/{function-or-resource}`
**Example:** `/aws/lambda/myapp-process-orders-prod`

---

## General AWS Tagging Recommendations

Include these tags on all resources for governance and cost management:

```json
{
  "Environment": "dev | staging | prod",
  "Project": "project-name",
  "ManagedBy": "cloudformation | terraform | manual",
  "Owner": "team-or-email",
  "CostCenter": "cost-center-id",
  "CreatedDate": "YYYY-MM-DD"
}
```

## Uniqueness Scope Summary

| Scope | Description | Examples |
|-------|-------------|---------|
| **Global** | Unique across all AWS accounts and regions | S3 buckets |
| **Account** | Unique within your AWS account (all regions) | IAM roles, policies |
| **Regional** | Unique within an account + region | Lambda, RDS, DynamoDB, ECS, EKS |
| **VPC** | Unique within a VPC | Security groups |

## References

- [AWS Resource Naming Rules](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)
- [IAM Naming](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html)
- [S3 Bucket Naming](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [RDS Naming Constraints](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html)
- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
