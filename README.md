# AWS Cloud Security Labs 🔐

Hands-on AWS Cloud Security labs built as part of my transition from 
ATM Security Consulting → Cloud Security Engineering.

**Author:** Mujtaba Hussain Naqvi  
**Role:** ATM Security Consultant & TMS Support Engineer  
**Location:** Karachi, Pakistan  
**LinkedIn:** [linkedin.com/in/mujtuba-hussain-132789227](https://linkedin.com/in/mujtuba-hussain-132789227)

---

## 🎯 Objective

Document real hands-on AWS security labs covering network isolation, 
IAM least privilege, S3 security, threat detection, audit logging, 
and Infrastructure as Code (IaC) security scanning.

---

## 📊 Labs Overview

| Lab | Topic | Status |
|-----|-------|--------|
| Lab 1 | VPC + Bastion Host + Network Isolation | ✅ Complete |
| Lab 2 | VPC Flow Logs + CloudWatch + Alerting | ✅ Complete |
| Lab 3 | IAM + Least Privilege + MFA | ✅ Complete |
| Lab 4 | S3 Security + Encryption + Versioning | ✅ Complete |
| Lab 5 | GuardDuty + Manual Linux Security Audit | ✅ Complete |
| Lab 6 | CloudTrail + API Audit Logging | ✅ Complete |
| Lab 7 | Terraform IaC + Checkov Security Scanning | ✅ Complete |

---

## 🏗️ Lab 1 — VPC + Bastion Host + Network Isolation

### What I built


Internet
↓
[Internet Gateway]
↓
[Public Subnet 10.0.10.0/24]
└── bastion-host (public IP, reachable by trusted IP only)
↓ SSH hop only
[Private Subnet 10.0.20.0/24]
└── private-server (NO public IP — internet blocked)
### Key concepts
- VPC with CIDR 10.0.0.0/16 — isolated private network
- Public subnet routes to IGW, private subnet has no internet route
- Security Group chaining — private server only accepts SSH from bastion SG
- Bastion host pattern — zero trust access control

### Proof of isolation
```bash
# From private server — no internet access
curl https://google.com --max-time 5
# curl: (28) Connection timed out after 5002 milliseconds

# Private IP only — no public IP exposed
ip addr show | grep inet
# inet 10.0.20.164/24
```

### Skills demonstrated
`VPC` `Subnets` `Internet Gateway` `Route Tables` `Security Groups` 
`Bastion Host` `SSH Key-pair Auth` `Network Isolation`

---

## 📡 Lab 2 — VPC Flow Logs + CloudWatch + Alerting

### What I built
- VPC Flow Logs capturing ALL traffic (ACCEPT + REJECT)
- CloudWatch Log Group `/vpc/flowlogs` with 7-day retention
- IAM role for Flow Logs → CloudWatch write permission
- SNS alarm for high traffic threshold (port scan detection)
- CloudWatch Logs Insights queries for SOC-style investigation

### Real attack traffic discovered
Within hours of deployment, real internet scanners were captured:

176.65.139.56  → port 22   → REJECT  (SSH brute force attempt)
212.73.148.20  → port 10624 → REJECT (port scanner)
212.73.148.25  → port 9090  → REJECT (port scanner)
45.142.193.35  → port 44058 → REJECT (scanner)

### CloudWatch Logs Insights query used
```sql
fields @timestamp, srcAddr, dstAddr, dstPort, action, protocol
| filter action = "REJECT"
| sort @timestamp desc
| limit 20
```

### Skills demonstrated
`VPC Flow Logs` `CloudWatch Logs Insights` `SNS Alerting` 
`Log Analysis` `Threat Identification` `SIEM-style Querying`

---

## 🔐 Lab 3 — IAM + Least Privilege + MFA

### What I built
- Account-wide password policy (12 chars, MFA, 90-day expiry)
- MFA enabled on root account
- IAM user `security-analyst` with zero permissions by default
- Custom policy `SecurityAnalystReadOnly` with explicit DENY rules

### Custom policy — least privilege
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "cloudwatch:GetMetricData",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:RunInstances",
        "ec2:CreateVpc",
        "ec2:DeleteVpc"
      ],
      "Resource": "*"
    }
  ]
}
```

### Verified
- ✅ Read EC2 instances — allowed
- ✅ Read CloudWatch logs — allowed  
- ❌ Terminate EC2 — Access Denied
- ❌ Create VPC — Access Denied (explicit deny confirmed)

### Skills demonstrated
`IAM Users` `Custom Policies` `Explicit Deny` `Least Privilege` 
`MFA` `Password Policy` `Access Control Testing`

---

## 🪣 Lab 4 — S3 Security + Encryption + Versioning

### What I built
- S3 bucket with all public access blocked
- SSE-S3 server-side encryption at rest
- HTTPS-only bucket policy (deny HTTP)
- Server access logging → `access-logs/` prefix
- Versioning enabled — ransomware protection

### Bucket policy — HTTPS only
```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::security-lab-logs/*",
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

### Verified
- Public URL access → `AccessDenied` confirmed
- Versioning → 2 versions of same file preserved (6.0B → 8.0B)

### Skills demonstrated
`S3 Bucket Policies` `SSE-S3 Encryption` `Public Access Block` 
`Versioning` `Access Logging` `HTTPS Enforcement`

---

## 🛡️ Lab 5 — GuardDuty + Manual Linux Security Audit

### What I built
- AWS GuardDuty enabled — automated threat detection
- Investigated Critical findings — cross-validated against raw JSON
- Manual Linux security audit on both bastion and private server

### Manual audit commands
```bash
# Check listening ports
ss -tlnp

# Check running processes
ps aux

# Check SSH auth logs
sudo cat /var/log/secure | grep -i "failed\|accepted"

# Check recent file changes
find /etc -newer /etc/passwd -type f

# Verify network isolation
ip route show
curl https://google.com --max-time 5
```

### Key finding
Private server only ever accepted connections from bastion 
internal IP `10.0.10.234` — never from the internet directly. 
Network isolation confirmed end-to-end.

### Skills demonstrated
`GuardDuty` `Threat Detection` `Finding Triage` `Linux Audit` 
`Log Analysis` `Incident Investigation`

---

## 📋 Lab 6 — CloudTrail + API Audit Logging

### What I built
- CloudTrail enabled across all regions
- Event history investigation for SOC-style incident reconstruction

### Key queries investigated

ConsoleLogin     → Who logged in, when, from which IP
RunInstances     → When EC2 instances were launched
CreateBucket     → When S3 bucket was created
DeleteBucket     → Detect unauthorized data deletion
AttachUserPolicy → Detect privilege escalation attempts

### Skills demonstrated
`CloudTrail` `API Audit Logging` `Incident Reconstruction` 
`SOC Investigation` `Event History Analysis`

---

## 🏗️ Lab 7 — Terraform IaC + Checkov Security Scanning

### What I built
- Complete VPC infrastructure deployed as Terraform code
- Checkov IaC security scanning — identified and fixed misconfigs
- Reduced security findings from 7 to 0

### Checkov findings fixed
| Check | Issue | Fix |
|-------|-------|-----|
| CKV_AWS_24 | SSH open to 0.0.0.0/0 | Restricted to trusted IP |
| CKV_AWS_130 | Public subnet auto-assigns IPs | Disabled |
| CKV2_AWS_11 | No VPC Flow Logs in code | Added aws_flow_log resource |
| CKV2_AWS_12 | Default SG not restricted | Added aws_default_security_group |
| CKV_AWS_158 | CloudWatch logs not KMS encrypted | Added aws_kms_key |
| CKV_AWS_338 | Log retention < 1 year | Set to 365 days |
| CKV2_AWS_41 | No IAM role on EC2 | Added instance profile |

### Terraform commands
```bash
terraform init    # Initialize providers
terraform plan    # Preview changes
terraform apply   # Deploy infrastructure
terraform destroy # Tear down everything
checkov -d .      # Scan for misconfigs
```

### Skills demonstrated
`Terraform` `IaC Security` `Checkov` `KMS Encryption` 
`Security Scanning` `DevSecOps` `Infrastructure Hardening`

---

## 🛠️ Tools & Technologies

| Category | Tools |
|----------|-------|
| Cloud Platform | AWS (ap-south-1 Mumbai) |
| IaC | Terraform, Checkov |
| SIEM | Wazuh, CloudWatch Logs Insights |
| Threat Detection | GuardDuty, CloudTrail |
| Security | IAM, Security Groups, KMS, VPC Flow Logs |
| OS | Amazon Linux 2023, Windows 11 |
| Languages | HCL (Terraform), JSON (IAM policies), Bash |

---

## 📈 Career Context

These labs are part of my transition from:

**ATM Security Consultant** (TouchPoint Pvt. Ltd — 17+ bank clients)  
→ **Cloud Security Engineer / SOC Analyst L1**

Current experience includes:
- Vynamic VAS deployment (Diebold Nixdorf ATMs)
- TMS platform administration (ActiveMQ, IIS, SQL Server)
- Wazuh SIEM operations
- Incident response and RCA documentation
- FortiClient VPN and firewall management

---

## 📜 Certifications (In Progress)
- CompTIA Security+ SY0-701 — studying
- AWS Cloud Practitioner CLF-C02 — planned

---

*Building in public. One lab at a time. 🚀*
