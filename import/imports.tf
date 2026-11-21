# Real IDs from your account (ap-southeast-2).
# Run with:  terraform plan "-generate-config-out=generated.tf"
# (delete generated.tf first if it already exists)

# ---------- Custom VPC: vishal-vpc (10.0.0.0/24) ----------
import {
  to = aws_vpc.vishal
  id = "vpc-01fd978a3add658f7"
}

# ---------- Custom subnet: vishal-subnet-01 (10.0.0.0/24, ap-southeast-2a) ----------
import {
  to = aws_subnet.vishal
  id = "subnet-0ade487bae6012af6"
}

# ---------- Custom route table (not main, no subnet associations) ----------
import {
  to = aws_route_table.vishal
  id = "rtb-0b4fc53acfd9215ff"
}

# ---------- EC2 instance (lives in the DEFAULT VPC, subnet-0a25ce43737a97bd2) ----------
import {
  to = aws_instance.web
  id = "i-09cfed59010231982"
}

# ---------- Instance security group (DEFAULT VPC) ----------
# Confirm its name is NOT "default" before importing (see instructions);
# a group named "default" must use aws_default_security_group instead.
import {
  to = aws_security_group.web
  id = "sg-0d03d184753e319e5"
}

# ---------- Optional: main route table of vishal-vpc ----------
# Only if you want Terraform to manage it (aws_default_route_table).
# Import ID is the VPC ID. Skip it if you never customized this table.
# import {
#   to = aws_default_route_table.vishal
#   id = "vpc-01fd978a3add658f7"
# }

# No internet gateway exists in vishal-vpc, and no subnet associations
# exist for rtb-0b4fc53acfd9215ff, so no IGW or association blocks are needed.