##########################
# RDS Database          #
##########################

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.prefix}-rds-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for RDS database"

  # Allow PostgreSQL access from ECS tasks
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
    description     = "PostgreSQL access from ECS tasks"
  }

  # Allow PostgreSQL access from Lambda function
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.hash_lambda_sg.id]
    description     = "PostgreSQL access from hash Lambda function"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.prefix}-rds-sg"
  }
}

# Subnet group for RDS (must be in private subnets)
resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

# Parameter group for PostgreSQL
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${local.prefix}-db-params"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${local.prefix}-db-params"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${local.prefix}-db"

  # Engine configuration
  engine         = "postgres"
  engine_version = "17.5"
  instance_class = "db.t3.micro" # Smallest instance class

  # Storage configuration
  allocated_storage     = 20 # 20 GB (minimum for PostgreSQL)
  max_allocated_storage = 25 # Maximum 25 GB as requested
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database configuration - conditional based on snapshot usage
  db_name  = var.use_snapshot ? null : local.db_name     # Use snapshot's db name if restoring
  username = var.use_snapshot ? null : local.db_username # Use snapshot's username if restoring
  password = var.use_snapshot ? null : local.db_password # Use snapshot's password if restoring
  port     = 5432

  # Snapshot configuration (only used if use_snapshot is true)
  snapshot_identifier = var.use_snapshot ? var.snapshot_identifier : null

  # Network configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  multi_az               = false # Single AZ for cost savings

  # Backup and maintenance
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  skip_final_snapshot       = false # As requested
  final_snapshot_identifier = "${local.prefix}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance insights
  performance_insights_enabled = false # Disabled for cost savings

  # Monitoring
  monitoring_interval = 0 # Disabled for cost savings

  # Deletion protection
  deletion_protection = false # Set to true in production

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  tags = {
    Name        = "${local.prefix}-db"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Outputs
output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "The port on which the DB accepts connections"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.identifier
} 