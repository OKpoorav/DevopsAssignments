"""Draws the Session 19 architecture diagram (architecture.png) with Pillow."""
from PIL import Image, ImageDraw, ImageFont

W, H = 1300, 820
img = Image.new("RGB", (W, H), (248, 250, 252))
d = ImageDraw.Draw(img)
F = "/System/Library/Fonts/Helvetica.ttc"
f_title, f_b, f_s = ImageFont.truetype(F, 26), ImageFont.truetype(F, 18), ImageFont.truetype(F, 14)


def box(xy, label, sub="", fill=(255, 255, 255), outline=(51, 65, 85), dash=False, w=2):
    x1, y1, x2, y2 = xy
    if dash:
        for x in range(x1, x2, 14):
            d.line([(x, y1), (min(x + 7, x2), y1)], fill=outline, width=w)
            d.line([(x, y2), (min(x + 7, x2), y2)], fill=outline, width=w)
        for y in range(y1, y2, 14):
            d.line([(x1, y), (x1, min(y + 7, y2))], fill=outline, width=w)
            d.line([(x2, y), (x2, min(y + 7, y2))], fill=outline, width=w)
    else:
        d.rounded_rectangle(xy, 10, fill=fill, outline=outline, width=w)
    d.text((x1 + 12, y1 + 8), label, font=f_b, fill=(15, 23, 42))
    for i, line in enumerate(sub.split("\n") if sub else []):
        d.text((x1 + 12, y1 + 34 + i * 18), line, font=f_s, fill=(71, 85, 105))


def arrow(p1, p2, label="", color=(37, 99, 235)):
    d.line([p1, p2], fill=color, width=3)
    import math
    a = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
    for s in (2.6, -2.6):
        d.line([p2, (p2[0] - 14 * math.cos(a + s / 6), p2[1] - 14 * math.sin(a + s / 6))], fill=color, width=3)
    if label:
        d.text(((p1[0] + p2[0]) / 2 + 6, (p1[1] + p2[1]) / 2 - 18), label, font=f_s, fill=color)


d.text((30, 20), "Session 19 - Terraform on AWS (us-east-1)  |  Poorav Kumar Gupta, 24bcs10080", font=f_title, fill=(15, 23, 42))

box((30, 100, 250, 250), "Terraform CLI", "init / plan / apply\ndestroy\nlocal terraform.tfstate\nproviders: aws, random", fill=(237, 233, 254))
box((30, 560, 250, 690), "User / Browser", "curl http://<public-ip>", fill=(254, 249, 195))
box((300, 80, 1270, 790), "AWS Region us-east-1", "", dash=True, outline=(234, 88, 12))
box((330, 130, 1010, 700), "VPC  10.20.0.0/16", "aws_vpc.main (DNS hostnames on)", fill=(239, 246, 255), outline=(37, 99, 235))
box((380, 210, 960, 560), "Public Subnet  10.20.1.0/24  (AZ: us-east-1a)", "aws_subnet.public  map_public_ip_on_launch = true", fill=(220, 252, 231), outline=(22, 163, 74))
box((430, 300, 900, 520), "Security Group  web-sg", "ingress tcp/80 from 0.0.0.0/0, egress all", fill=(254, 242, 242), outline=(220, 38, 38))
box((480, 380, 850, 500), "EC2  t3.micro", "Amazon Linux 2023 (data.aws_ami)\nnginx via user_data, IMDSv2, gp3 8GB enc.", fill=(255, 237, 213), outline=(234, 88, 12))
box((380, 590, 700, 680), "Route Table (public)", "0.0.0.0/0 -> IGW, assoc. to subnet", fill=(255, 255, 255))
box((760, 590, 990, 680), "Internet Gateway", "aws_internet_gateway.main", fill=(255, 255, 255))
box((1040, 150, 1250, 330), "S3 Bucket", "poorav-s19-assets-<hex>\nSSE AES256\nPublic access blocked\n(random_id suffix)", fill=(236, 252, 203), outline=(101, 163, 13))

arrow((250, 175), (330, 175), "")
d.text((255, 145), "manages", font=f_s, fill=(37, 99, 235))
arrow((250, 175), (1040, 240), "")
d.line([(250, 660), (280, 740), (875, 740)], fill=(37, 99, 235), width=3)
arrow((875, 740), (875, 682), "")
d.text((520, 746), "HTTP :80 -> IGW -> public IP of EC2", font=f_s, fill=(37, 99, 235))
arrow((875, 590), (760, 470), "")
arrow((540, 590), (540, 560), "")
d.text((1040, 360), "Dependencies", font=f_b, fill=(15, 23, 42))
for i, t in enumerate(["implicit: subnet -> vpc", "implicit: igw/rt/sg -> vpc", "implicit: ec2 -> subnet, sg, ami",
                       "implicit: bucket -> random_id", "explicit: ec2 depends_on", "   route_table_association"]):
    d.text((1040, 392 + i * 22), t, font=f_s, fill=(71, 85, 105))
img.save("screenshots/architecture.png")
print("saved screenshots/architecture.png")
