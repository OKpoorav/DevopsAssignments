#!/bin/bash
set -eux
dnf install -y nginx
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat > /usr/share/nginx/html/index.html <<HTML
<!doctype html>
<html><head><title>Session 19 - Terraform on AWS</title>
<style>body{font-family:sans-serif;background:#0f172a;color:#e2e8f0;text-align:center;padding-top:80px}h1{color:#38bdf8}</style></head>
<body>
<h1>Hello from Terraform on AWS EC2!</h1>
<p>Poorav Kumar Gupta &middot; 24bcs10080 &middot; Session 19</p>
<p>Instance: $IID &middot; AZ: $AZ</p>
<p>VPC &rarr; Subnet &rarr; Security Group &rarr; EC2 (nginx) + S3</p>
</body></html>
HTML
systemctl enable --now nginx
