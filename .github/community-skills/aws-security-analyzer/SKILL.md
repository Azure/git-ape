---
name: aws-security-analyzer
description: "Analyze CloudFormation templates and AWS resource configurations against security best practices. Produces per-resource security assessment with severity ratings. Use during template generation before deployment confirmation or to audit existing AWS configurations."
argument-hint: "CloudFormation template JSON/YAML or list of AWS resource configurations to analyze"
user-invocable: true
last_updated: "2026-04-15"
---

# AWS Security Analyzer

Analyze AWS resource configurations and CloudFormation templates against security best practices. Produces a per-resource security assessment report with severity ratings and actionable recommendations.

## When to Use

- During CloudFormation template creation — analyze before deployment
- To audit an existing template for security gaps
- When user asks "is this secure?" or "check security" for an AWS deployment
- Post-deployment security review of resource configurations

## Verification Integrity Rules (CRITICAL)

**Every claim in the security report MUST be verifiable against the CloudFormation template or resource configuration.** Never fabricate, assume, or misrepresent security status.

### Rule 1: Cite Exact Evidence

Every "✅ Applied" status **MUST cite the exact CloudFormation property path and its value** that proves the control is in place. If you cannot point to a specific property in the template, you cannot mark it as applied.

```markdown
# ✅ CORRECT — cites exact property
| Encryption at rest | 🔴 Critical | ✅ Applied | `Properties.StorageEncrypted: true` | Explicitly set in template |

# ❌ WRONG — no evidence from template
| Encryption at rest | 🔴 Critical | ✅ Applied | N/A | AWS encrypts RDS by default |
```

### Rule 2: Distinguish Explicit Config vs AWS Defaults

AWS provides some security controls by default. These are NOT the same as explicitly configured controls.

| Status | Icon | Meaning | When to Use |
|--------|------|---------|-------------|
| **✅ Applied** | ✅ | Explicitly configured in the CloudFormation template | Property exists in template with secure value |
| **🔄 AWS Default** | 🔄 | AWS provides this automatically, NOT in template | Control exists due to AWS platform behavior, not template config |
| **⚠️ Not applied** | ⚠️ | Control is missing and should be considered | Property absent from template, no AWS default covers it |
| **❌ Misconfigured** | ❌ | Property exists but set to an insecure value | Property in template with wrong/insecure value |

### Rule 3: Never Use Misleading Framing

Describe security status **accurately and literally**. Do not soften or reframe risks.

### Rule 4: Verify Before Reporting

Before generating the security report:
1. Re-read the CloudFormation template or configuration
2. For each "✅ Applied" entry: search the template for the cited property
3. For network exposure: check if any resource has a public IP or is publicly accessible
4. For encryption claims: distinguish between AWS default encryption and explicitly configured encryption
5. Cross-check property paths — use correct CloudFormation property names

### Rule 5: When Uncertain, Mark as Unknown

```markdown
| {check} | {severity} | ❓ Unknown | {property} | Unable to verify — property path unclear |
```

**Never guess. Never fabricate. When in doubt, flag it.**

## Security Checklists by Service

### S3 Buckets

| Check | Severity | Property Path |
|-------|----------|--------------|
| Block public access | 🔴 Critical | `Properties.PublicAccessBlockConfiguration.BlockPublicAcls: true` + all 4 flags |
| Encryption at rest | 🔴 Critical | `Properties.BucketEncryption.ServerSideEncryptionConfiguration` |
| Versioning enabled | 🟠 High | `Properties.VersioningConfiguration.Status: Enabled` |
| Access logging | 🟡 Medium | `Properties.LoggingConfiguration` |
| MFA delete | 🟡 Medium | CLI/SDK only — cannot set via CloudFormation |
| HTTPS-only bucket policy | 🟠 High | `AWS::S3::BucketPolicy` with `aws:SecureTransport: false` deny |

### IAM Roles and Policies

| Check | Severity | Property Path |
|-------|----------|--------------|
| No wildcard actions on sensitive services | 🔴 Critical | Check `Action: "*"` or `Action: "s3:*"` in policy statements |
| No wildcard resources with sensitive actions | 🔴 Critical | Check `Resource: "*"` paired with write/admin actions |
| MFA condition for sensitive roles | 🟠 High | `Condition.Bool.aws:MultiFactorAuthPresent: true` in trust policy |
| ExternalId for cross-account roles | 🟠 High | `Condition.StringEquals.sts:ExternalId` in trust policy |
| Permission boundary | 🟡 Medium | `Properties.PermissionsBoundary` |

### Lambda Functions

| Check | Severity | Property Path |
|-------|----------|--------------|
| Dedicated execution role (not AdministratorAccess) | 🔴 Critical | `Properties.Role` — check attached role policies |
| Environment variable encryption | 🟠 High | `Properties.KmsKeyArn` for KMS encryption of env vars |
| VPC configuration (if accessing private resources) | 🟡 Medium | `Properties.VpcConfig` |
| Reserved concurrency set | 🔵 Low | `Properties.ReservedConcurrentExecutions` |
| No secrets in environment variables | 🔴 Critical | Check `Properties.Environment.Variables` values |

### EC2 Instances

| Check | Severity | Property Path |
|-------|----------|--------------|
| IMDSv2 required | 🔴 Critical | `Properties.MetadataOptions.HttpTokens: required` |
| No public IP (backend instances) | 🔴 Critical | `Properties.NetworkInterfaces[].AssociatePublicIpAddress: false` |
| EBS volumes encrypted | 🟠 High | `Properties.BlockDeviceMappings[].Ebs.Encrypted: true` |
| IAM instance profile (not access keys) | 🔴 Critical | `Properties.IamInstanceProfile` |
| Security group not open to 0.0.0.0/0 on port 22 | 🔴 Critical | Check `AWS::EC2::SecurityGroup` ingress rules |

### RDS Instances

| Check | Severity | Property Path |
|-------|----------|--------------|
| Storage encrypted | 🔴 Critical | `Properties.StorageEncrypted: true` |
| Not publicly accessible | 🔴 Critical | `Properties.PubliclyAccessible: false` |
| Multi-AZ enabled (prod) | 🟠 High | `Properties.MultiAZ: true` |
| Backup retention period | 🟠 High | `Properties.BackupRetentionPeriod >= 7` |
| Deletion protection | 🟠 High | `Properties.DeletionProtection: true` |
| SSL enforcement | 🟡 Medium | Parameter group `rds.force_ssl: 1` |

### ECS/EKS

| Check | Severity | Property Path (ECS) |
|-------|----------|---------------------|
| Task role (not execution role) for app permissions | 🔴 Critical | `Properties.TaskRoleArn` in task definition |
| Secrets from Secrets Manager (not env vars) | 🔴 Critical | Container `secrets` array, not `environment` |
| Private subnets only | 🟠 High | `Properties.NetworkConfiguration.AwsvpcConfiguration.AssignPublicIp: DISABLED` |
| Container read-only root filesystem | 🟡 Medium | Container `readonlyRootFilesystem: true` |
| No privileged containers | 🔴 Critical | Container `privileged: false` or absent |

## Procedure

### 1. Extract Resources from Template

Parse the CloudFormation template to identify all resources and their types:
- `AWS::S3::Bucket`
- `AWS::IAM::Role` / `AWS::IAM::Policy`
- `AWS::Lambda::Function`
- `AWS::EC2::Instance` / `AWS::EC2::SecurityGroup`
- `AWS::RDS::DBInstance`
- `AWS::ECS::TaskDefinition` / `AWS::EKS::Cluster`
- etc.

### 2. Run Security Checks

For each resource, apply the relevant service checklist above. For each check:
1. Search the template JSON/YAML for the exact property path
2. Determine status: ✅ Applied, 🔄 AWS Default, ⚠️ Not applied, ❌ Misconfigured
3. Record the actual property value found (or "absent" if not in template)

### 3. Format Report

For each resource, produce a security table:

```markdown
### 🪣 S3: my-data-bucket (AWS::S3::Bucket)

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| Block public access | 🔴 Critical | ✅ Applied | `PublicAccessBlockConfiguration.BlockPublicAcls: true` (all 4 flags set) | |
| Encryption at rest | 🔴 Critical | ✅ Applied | `BucketEncryption.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm: aws:kms` | |
| Versioning | 🟠 High | ✅ Applied | `VersioningConfiguration.Status: Enabled` | |
| Access logging | 🟡 Medium | ⚠️ Not applied | `LoggingConfiguration` absent | Consider enabling for audit trail |
| HTTPS-only policy | 🟠 High | ⚠️ Not applied | No bucket policy found | Add deny for aws:SecureTransport: false |
```

### 4. Evaluate Security Gate

After analyzing all resources:

**Count critical and high severity issues that are ⚠️ Not applied or ❌ Misconfigured.**

```markdown
## 🔒 Security Gate

| Severity | Total Checks | ✅ Passed | ⚠️ Issues |
|----------|-------------|---------|---------|
| 🔴 Critical | X | Y | Z |
| 🟠 High | X | Y | Z |
| 🟡 Medium | X | Y | Z |
| 🔵 Low | X | Y | Z |
```

**If Z (Critical + High issues) = 0:**

```markdown
## 🟢 SECURITY GATE: PASSED

All Critical and High severity checks pass. Deployment may proceed.
```

**If Z (Critical + High issues) > 0:**

```markdown
## 🔴 SECURITY GATE: BLOCKED

{N} Critical/High severity issue(s) must be resolved before deployment.

### Required Fixes:
1. [Resource Name] — [Check]: [Recommended fix with exact CloudFormation property]
2. ...

**Options:**
A. Accept proposed fixes → I will update the template and re-run security analysis
B. Provide alternative security settings → I will incorporate and re-run
C. Override: type "I accept the security risk" (will be logged as OVERRIDDEN)
```

The gate loops until PASSED or explicitly overridden — no shortcutting allowed.

### 5. Propose Fixes

For each issue, provide the exact CloudFormation YAML or JSON change needed:

```yaml
# Fix: Enable S3 encryption
Properties:
  BucketEncryption:
    ServerSideEncryptionConfiguration:
      - ServerSideEncryptionByDefault:
          SSEAlgorithm: aws:kms
          KMSMasterKeyID: !Ref MyKMSKey

# Fix: Require IMDSv2 on EC2
Properties:
  MetadataOptions:
    HttpTokens: required
    HttpEndpoint: enabled
```

## Severity Classification

| Level | Icon | Definition |
|-------|------|-----------|
| **Critical** | 🔴 | Direct path to data breach, privilege escalation, or data loss. Must fix. |
| **High** | 🟠 | Significantly increases attack surface or blast radius. Should fix. |
| **Medium** | 🟡 | Defense-in-depth control. Recommended for production. |
| **Low** | 🔵 | Minor hardening. Nice-to-have. |

## References

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CloudFormation Security](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/security.html)
