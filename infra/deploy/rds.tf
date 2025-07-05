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

  # Allow PostgreSQL access from new private NAT subnet
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_nat.cidr_block]
    description = "PostgreSQL access from new private NAT subnet"
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
  cpu                      = 128
  network_mode             = "awsvpc"
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name              = "db-init"
      image             = "ubuntu:22.04"
      essential         = true
      memoryReservation = 256

      command = [
        "sh", "-c",
        <<-EOT
          set -e
          echo "=== Database Initialization Started ==="
          echo "Timestamp: $(date)"
          echo "Container started successfully!"
          echo "Environment variables:"
          echo "  DB_HOST: $DB_HOST"
          echo "  DB_NAME: $DB_NAME"
          echo "  DB_USER: $DB_USER"
          echo "  DB_PASSWORD: [REDACTED]"
          echo "Current working directory: $(pwd)"
          echo "Available commands:"
          echo "  which psql: $(which psql 2>/dev/null || echo 'psql not found')"
          echo "  which apt-get: $(which apt-get)"
          
          # Install PostgreSQL client
          echo "Installing PostgreSQL client..."
          apt-get update && apt-get install -y postgresql-client
          echo "PostgreSQL client installation completed"
          echo "psql version: $(psql --version)"
          
          echo "Testing database connection..."
          echo "Attempting to connect to: $DB_HOST:$DB_NAME as user: $DB_USER"
          
          # Test connection first
          if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT version();"; then
            echo "Database connection successful!"
          else
            echo "ERROR: Failed to connect to database"
            echo "Connection details:"
            echo "  Host: $DB_HOST"
            echo "  Database: $DB_NAME"
            echo "  User: $DB_USER"
            echo "  Port: 5432 (default)"
            exit 1
          fi
          
          echo "Writing initialization script..."
          cat > /tmp/init-database.sql << 'SQL_SCRIPT'
          ${file("${path.module}/scripts/init-database.sql")}
          SQL_SCRIPT
          echo "Initialization script written to /tmp/init-database.sql"
          echo "Script size: $(wc -l < /tmp/init-database.sql) lines"
          echo "Running database initialization script..."
          
          # Run the initialization script
          if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f /tmp/init-database.sql; then
            echo "Database initialization script executed successfully"
          else
            echo "ERROR: Database initialization script failed"
            exit 1
          fi
          
          echo "=== Database Initialization Completed Successfully ==="
          echo "Timestamp: $(date)"
          echo "All tables and schemas have been created."
        EOT
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

# Database Initialization using null_resource and AWS CLI
resource "null_resource" "db_init" {
  depends_on = [aws_db_instance.main]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Starting Database Initialization Task ==="
      echo "Timestamp: $(date)"
      echo "Database Endpoint: ${aws_db_instance.main.endpoint}"
      echo "Task Definition: ${aws_ecs_task_definition.db_init.family}:${aws_ecs_task_definition.db_init.revision}"
      
      # Run the ECS task
      TASK_ARN=$(aws ecs run-task \
        --cluster ${aws_ecs_cluster.main.name} \
        --task-definition ${aws_ecs_task_definition.db_init.family}:${aws_ecs_task_definition.db_init.revision} \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.private_a.id},${aws_subnet.private_b.id}],securityGroups=[${aws_security_group.ecs_service.id}],assignPublicIp=DISABLED}" \
        --region ${data.aws_region.current.name} \
        --query 'tasks[0].taskArn' \
        --output text)
      
      echo "Task ARN: $TASK_ARN"
      echo "Waiting for task to complete..."
      
      # Wait for task to complete
      aws ecs wait tasks-stopped \
        --cluster ${aws_ecs_cluster.main.name} \
        --tasks $TASK_ARN \
        --region ${data.aws_region.current.name}
      
      # Get task status
      TASK_STATUS=$(aws ecs describe-tasks \
        --cluster ${aws_ecs_cluster.main.name} \
        --tasks $TASK_ARN \
        --region ${data.aws_region.current.name} \
        --query 'tasks[0].lastStatus' \
        --output text)
      
      echo "Task Status: $TASK_STATUS"
      
      # Check if task succeeded
      if [ "$TASK_STATUS" = "STOPPED" ]; then
        EXIT_CODE=$(aws ecs describe-tasks \
          --cluster ${aws_ecs_cluster.main.name} \
          --tasks $TASK_ARN \
          --region ${data.aws_region.current.name} \
          --query 'tasks[0].containers[0].exitCode' \
          --output text)
        
        echo "Container Exit Code: $EXIT_CODE"
        
        if [ "$EXIT_CODE" = "0" ]; then
          echo "=== Database Initialization SUCCESSFUL ==="
          echo "Timestamp: $(date)"
          echo "Check CloudWatch logs at: /aws/ecs/${local.project_name}/db-init"
        else
          echo "=== Database Initialization FAILED ==="
          echo "Timestamp: $(date)"
          echo "Exit Code: $EXIT_CODE"
          echo "Check CloudWatch logs at: /aws/ecs/${local.project_name}/db-init"
          exit 1
        fi
      else
        echo "=== Database Initialization FAILED ==="
        echo "Timestamp: $(date)"
        echo "Task did not complete properly. Status: $TASK_STATUS"
        echo "Check CloudWatch logs at: /aws/ecs/${local.project_name}/db-init"
        exit 1
      fi
    EOT
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