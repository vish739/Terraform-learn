# Terraform Import Existing AWS Resources
 
## Objective
 
Import existing AWS resources into Terraform state and create Terraform configuration that accurately reflects the existing infrastructure.
 
## Resources Imported
 
| Resource Type | Terraform Resource | AWS ID |
|--------------|-------------------|---------|
| VPC | aws_vpc.vishal | vpc-01fd978a3add658f7 |
| Subnet | aws_subnet.vishal | subnet-0ade487bae6012af6 |
| Route Table | aws_route_table.vishal | rtb-0b4fc53acfd9215ff |
| Security Group | aws_security_group.web | sg-0d03d184753e319e5 |
| EC2 Instance | aws_instance.web | i-09cfed59010231982 |
 
---
 
# Prerequisites
 
Verify AWS credentials:
 
```powershell
aws sts get-caller-identity
```
 
Verify Terraform installation:
 
```powershell
terraform version
```
 
Initialize Terraform:
 
```powershell
terraform init
```
 
---
 
# Step 1 - Create Import Blocks
 
Create `import.tf`
 
```hcl
import {
to = aws_vpc.vishal
id = "vpc-01fd978a3add658f7"
}
 
import {
to = aws_subnet.vishal
id = "subnet-0ade487bae6012af6"
}
 
import {
to = aws_route_table.vishal
id = "rtb-0b4fc53acfd9215ff"
}
 
import {
to = aws_security_group.web
id = "sg-0d03d184753e319e5"
}
 
import {
to = aws_instance.web
id = "i-09cfed59010231982"
}
```
 
---
 
# Step 2 - Generate Terraform Configuration
 
Attempt automatic configuration generation:
 
```powershell
terraform plan -generate-config-out=generated.tf
```
 
Terraform successfully discovered the resources but generated invalid configuration.
 
---
 
# Step 3 - Review Generated Configuration
 
The generated file contained several invalid arguments.
 
## Subnet Issues
 
Remove:
 
```hcl
availability_zone_id
enable_lni_at_device_index
customer_owned_ipv4_pool
map_customer_owned_ip_on_launch
outpost_arn
ipv6_cidr_block
```
 
### Error
 
```text
availability_zone conflicts with availability_zone_id
```
 
### Error
 
```text
enable_lni_at_device_index must not be zero
```
 
### Error
 
```text
map_customer_owned_ip_on_launch
```
 
---
 
## VPC Issues
 
Remove:
 
```hcl
ipv4_ipam_pool_id
ipv4_netmask_length
ipv6_ipam_pool_id
ipv6_netmask_length
```
 
### Error
 
```text
ipv6_netmask_length must be specified with ipv6_ipam_pool_id
```
 
---
 
## EC2 Issues
 
Remove:
 
```hcl
ipv6_address_count
ipv6_addresses
```
 
### Error
 
```text
ipv6_address_count conflicts with ipv6_addresses
```
 
---
 
# Step 4 - Create Minimal main.tf
 
Created a clean Terraform configuration.
 
```hcl
resource "aws_vpc" "vishal" {
cidr_block = "10.0.0.0/24"
 
tags = {
Name = "vishal-vpc"
}
}
 
resource "aws_subnet" "vishal" {
vpc_id = aws_vpc.vishal.id
cidr_block = "10.0.0.0/24"
availability_zone = "ap-southeast-2a"
 
tags = {
Name = "vishal-subnet-01"
}
}
 
resource "aws_route_table" "vishal" {
vpc_id = aws_vpc.vishal.id
 
tags = {
Name = "vishal-route"
}
}
 
resource "aws_security_group" "web" {
name = "launch-wizard-1"
description = "launch-wizard-1 created 2026-11-21T17:37:53.634Z"
 
vpc_id = "vpc-000f63a6d4be992e9"
 
ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
 
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
 
tags = {}
}
 
resource "aws_instance" "web" {
ami = "ami-0331e43da0c1f186e"
instance_type = "t3.micro"
 
subnet_id = "subnet-0a25ce43737a97bd2"
 
tags = {
Name = "vishal-ec2"
}
}
```
 
---
 
# Step 5 - Fix Encoding Issues
 
Terraform reported:
 
```text
Invalid character
Invalid character encoding
```
 
Root cause:
 
```text
Â
�
```
 
characters were accidentally introduced during copy/paste.
 
Solution:
 
1. Delete corrupted file.
2. Recreate `main.tf`.
3. Save as UTF-8.
 
---
 
# Step 6 - Fix Provider Configuration
 
Terraform reported:
 
```text
Duplicate provider configuration
```
 
Cause:
 
Provider block existed in both:
 
```text
providers.tf
main.tf
```
 
Solution:
 
Keep provider only in:
 
```text
providers.tf
```
 
Remove from:
 
```text
main.tf
```
 
---
 
# Step 7 - Validate Configuration
 
Format code:
 
```powershell
terraform fmt
```
 
Validate syntax:
 
```powershell
terraform validate
```
 
Initialize:
 
```powershell
terraform init
```
 
---
 
# Step 8 - Review Terraform Plan
 
Run:
 
```powershell
terraform plan
```
 
Initial result:
 
```text
aws_security_group.web must be replaced
```
 
Cause:
 
Security group rules were missing from configuration.
 
Added ingress and egress rules to match AWS.
 
---
 
# Step 9 - Final Verification
 
Run:
 
```powershell
terraform plan
```
 
Result:
 
```text
No changes. Your infrastructure matches the configuration.
```
 
---
 
# Useful Commands
 
## View Imported Resources
 
```powershell
terraform state list
```
 
## Inspect a Resource
 
```powershell
terraform state show aws_instance.web
```
 
```powershell
terraform state show aws_vpc.vishal
```
 
```powershell
terraform state show aws_security_group.web
```
 
## Show Entire State
 
```powershell
terraform show
```
 
## Validate Configuration
 
```powershell
terraform validate
```
 
## Generate Execution Plan
 
```powershell
terraform plan
```
 
---
 
# Key Learnings
 
- Importing resources adds them to Terraform state.
- Terraform still requires valid configuration files.
- `terraform plan -generate-config-out` is experimental and may generate invalid AWS resource arguments.
- Generated configurations should always be reviewed and cleaned up.
- Encoding issues (`Â`, `�`) can break Terraform parsing.
- A successful import is confirmed when:
 
```text
terraform plan
```
 
returns:
 
```text
No changes. Your infrastructure matches the configuration.
```
 
---
 
# Final Outcome
 
Successfully imported existing AWS infrastructure into Terraform:
 
- Custom VPC
- Custom Subnet
- Route Table
- Security Group
- EC2 Instance
 
Terraform state and AWS infrastructure are now fully synchronized.
 
✅ Import Successful
 
✅ Configuration Valid
 
✅ No Drift Detected
 
✅ Terraform Ready for Ongoing Management