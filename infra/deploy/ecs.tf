########################################################
# ECS Task end Executrion. This section controls       #
# The deployement of app/proxy and app/web containers. #
########################################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.prefix}-ecs-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECR and S3 access
resource "aws_iam_policy" "ecs_access_policy" {
  name        = "${var.prefix}-ecs-access-policy"
  description = "Policy for ECS tasks to pull images from ECR and read from S3 sources folder"
  policy      = data.aws_iam_policy_document.ecs_access.json
}

# Consolidated policy document for ECR and S3 access
data "aws_iam_policy_document" "ecs_access" {
  # ECR permissions
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = [
      data.aws_ecr_repository.proxy_repo.arn,
      data.aws_ecr_repository.app_repo.arn
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # S3 permissions for sources folder
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]
    resources = [
      data.aws_s3_bucket.existing.arn,
      "${data.aws_s3_bucket.existing.arn}/sources*"
    ]
  }

  # CloudWatch Logs permissions
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/ecs/${local.project_name}/*"]
  }

  # ELB permissions for target group registration
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["*"]
  }
}

# Attach the consolidated access policy to the task execution role
resource "aws_iam_role_policy_attachment" "ecs_access_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_access_policy.arn
}

################
# ECS Cluster  #
################
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"
  tags = {
    Name = "${local.prefix}-cluster"
  }
}

###############################
# Actual Tasks related to ECS #
###############################

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.prefix}-web"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  network_mode             = "awsvpc"
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # List of policies of what ecs can do.
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn # allows for the asumption of polices above.

  container_definitions = jsonencode(
    [
      {
        name              = "web"
        image             = var.ecr_app_image
        essential         = true
        memoryReservation = 256
        user              = "www-data"
        portMappings = [
          {
            containerPort = 5000
            hostPort      = 5000
          }
        ]
        environment = [
          {
            name  = "ALLOWED_HOSTS"
            value = "*" # to be changed when Domain names declared
          },
          {
            name  = "CLOUDFRONT_URL"
            value = local.cloudfront_url
          },
          {
            name  = "S3_BUCKET_NAME"
            value = local.s3_bucket_name
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/aws/ecs/${local.project_name}/web"
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "api"
          }
        }
      },
      {
        name              = "proxy"
        image             = var.ecr_proxy_image
        essential         = true
        memoryReservation = 256
        user              = "nginx"
        portMappings = [
          {
            containerPort = 8000
            hostPort      = 8000
          }
        ]
        environment = [
          {
            name  = "APP_HOST"
            value = "127.0.0.1"
          },
          {
            name  = "FLASK_PORT"
            value = "5000"
          },
          {
            name  = "PROXY_PORT"
            value = "8000"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/aws/ecs/${local.project_name}/proxy"
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "terra-proxy"
          }
        }
      }
    ]
  )

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # must match what the docker is built for!
  }
}

resource "aws_security_group" "ecs_service" {
  description = "outgoing rules for ECS"
  name        = "${local.prefix}-ecs-service"
  vpc_id      = aws_vpc.main.id

  # Access to end points
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound access from internet via Load balancer
  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    security_groups = [
      aws_security_group.loadbalancer.id
    ]
  }
}

resource "aws_ecs_service" "web" {
  name                   = "${local.prefix}-web"
  cluster                = aws_ecs_cluster.main.name
  task_definition        = aws_ecs_task_definition.web.family
  desired_count          = 2
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {

    subnets = [ # also atypical. Will eventually be behind a load balancer.
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web_app.arn
    container_name   = "proxy"
    container_port   = 8000
  }
}

# Application Auto Scaling for ECS Service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based scaling policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "${local.prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Memory-based scaling policy
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "${local.prefix}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# CloudWatch Log Groups for ECS
resource "aws_cloudwatch_log_group" "ecs_web" {
  name              = "/aws/ecs/${local.project_name}/web"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ecs_proxy" {
  name              = "/aws/ecs/${local.project_name}/proxy"
  retention_in_days = 14
}