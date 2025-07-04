resource "aws_security_group" "console_access" {
  name        = "console-ssh-access"
  description = "Allow SSH from AWS Console IP range for NAT subnet resources"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH from AWS Console"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["18.237.140.160/29"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow all outbound traffic"
  }

  tags = {
    Name = "console-ssh-access"
  }
} 