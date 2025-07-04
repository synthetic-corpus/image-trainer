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
  identifier                 = "${local.prefix}-db"
  allocated_storage          = 100   # in gb. Min size of io1 and postgres
  storage_type               = "io1" # "gp2" for simplest
  engine                     = "postgres"
  engine_version             = "15.13"
  auto_minor_version_upgrade = true
  instance_class             = "db.t4g.micro" # "db.t4g.micro" for simplest
  iops                       = 2000           # 50x100 = 5000. 5000 would be the max here
  storage_encrypted          = true

  # Database configuration - conditional based on snapshot usage
  db_name  = var.use_snapshot ? null : local.db_name     # Use snapshot's db name if restoring
  username = var.use_snapshot ? null : local.db_username # Use snapshot's username if restoring
  password = var.use_snapshot ? null : local.db_password # Use snapshot's password if restoring
  port     = 5432

  # Snapshot configuration (only used if use_snapshot is true)
  skip_final_snapshot = false
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
    Name        = "mldatabase"
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

#######################################
# Database Initialization ECS Task   #
#######################################

# ECS Task Definition for Database Initialization
resource "aws_ecs_task_definition" "db_init" {
  family                   = "${local.prefix}-db-init"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  network_mode             = "awsvpc"
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "db-init"
      image = "postgres:15"
      essential = true
      memoryReservation = 256
      
      command = [
        "sh", "-c",
        "echo '${file("${path.module}/scripts/init-database.sql")}' > /tmp/init-database.sql && PGPASSWORD=$$DB_PASSWORD psql -h $$DB_HOST -U $$DB_USER -d $$DB_NAME -f /tmp/init-database.sql"
      ]
      
      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.main.endpoint
        },
        {
          name  = "DB_NAME"
          value = local.db_name
        },
        {
          name  = "DB_USER"
          value = local.db_username
        },
        {
          name  = "DB_PASSWORD"
          value = local.db_password
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/${local.project_name}/db-init"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "db-init"
        }
      }
    }
  ])



  tags = {
    Name = "${local.prefix}-db-init-task"
  }
}

# ECS Task for Database Initialization (runs once)
resource "aws_ecs_task" "db_init_task" {
  cluster           = aws_ecs_cluster.main.id
  task_definition   = aws_ecs_task_definition.db_init.arn
  launch_type       = "FARGATE"
  
  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.ecs_service.id]
  }
  
  depends_on = [aws_db_instance.main]
  
  # Task runs once and exits
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for DB Init
resource "aws_cloudwatch_log_group" "ecs_db_init" {
  name              = "/aws/ecs/${local.project_name}/db-init"
  retention_in_days = 7

  tags = {
    Name = "${local.prefix}-db-init-logs"
  }
} 