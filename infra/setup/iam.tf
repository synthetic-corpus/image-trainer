#########################################
# Creates IAM user and its polices for CD
#########################################

# 'resource' is something that is created in AWS.
resource "aws_iam_user" "cd" {
  name = "${var.project}-setup-guy"
}

resource "aws_iam_access_key" "cd" {
  user = aws_iam_user.cd.name
}

##########################################################
# The Policies. For bare minimum Terraform Functionality #
##########################################################

# 'data' is information that a resource will use when it is created
data "aws_iam_policy_document" "tf_backend_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}/${var.project}-deploy*",
      "arn:aws:s3:::${var.tf_state_bucket}/${var.project}-deploy-env*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.tf_state_lock_table}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:DeleteBucketNotification"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "tf_backend_policy" {
  name        = "${aws_iam_user.cd.name}-${var.project}-s3-dynamodb"
  description = "Allows user to use S3 and DynamoDB for Terraform resources"
  policy      = data.aws_iam_policy_document.tf_backend_document.json
}

# This attaches the policy to the user
resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.tf_backend_policy.arn
}

##########################################################
# Policies related to what is actually deployed.        #
##########################################################

###############################
# Consolidated Infrastructure Policy #
###############################

data "aws_iam_policy_document" "infrastructure" {
  # EC2/VPC permissions
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeAddresses",
      "ec2:DescribeVpcs",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeSecurityGroups",
      "ec2:DeleteSubnet",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DetachInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:DeleteInternetGateway",
      "ec2:DetachNetworkInterface",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeRouteTables",
      "ec2:DeleteRouteTable",
      "ec2:DeleteVpcEndpoints",
      "ec2:DisassociateRouteTable",
      "ec2:DeleteRoute",
      "ec2:DescribePrefixLists",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeNetworkAcls",
      "ec2:AssociateRouteTable",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateSecurityGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:CreateVpcEndpoint",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateSubnet",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:ModifyVpcAttribute",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeImages",
      "ec2:DescribeKeyPairs",
      "ec2:CreateNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:AssociateIamInstanceProfile",
      "ec2:DisassociateIamInstanceProfile",
      "ec2:DescribeIamInstanceProfileAssociations",
      "ec2:DescribeInstanceAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeVolumes",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DescribeSnapshots",
      "ec2:DescribeInstanceCreditSpecifications",
      "ec2:CreateInstanceConnectEndpoint",
      "ec2:DeleteInstanceConnectEndpoint",
      "ec2:DescribeInstanceConnectEndpoints",
      "ec2-instance-connect:SendSSHPublicKey",
    ]
    resources = ["*"]
  }

  # ECS permissions
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DeregisterTaskDefinition",
      "ecs:DeleteCluster",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:DeleteService",
      "ecs:DescribeTaskDefinition",
      "ecs:CreateService",
      "ecs:RegisterTaskDefinition",
      "ecs:CreateCluster",
      "ecs:UpdateCluster",
      "ecs:TagResource",
      "ecs:ListServices",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
      "ecs:StopTask",
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:DescribeTaskSets",
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:UpdateTaskSet"
    ]
    resources = ["*"]
  }

  # Lambda permissions
  statement {
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:CreateAlias",
      "lambda:DeleteAlias",
      "lambda:UpdateAlias",
      "lambda:GetAlias",
      "lambda:InvokeFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:PublishVersion",
      "lambda:CreateEventSourceMapping",
      "lambda:DeleteEventSourceMapping",
      "lambda:GetEventSourceMapping",
      "lambda:ListEventSourceMappings",
      "lambda:UpdateEventSourceMapping",
      "lambda:ListFunctions",
      "lambda:ListLayers",
      "lambda:GetLayerVersion",
      "lambda:CreateLayerVersion",
      "lambda:DeleteLayerVersion",
      "lambda:ListLayerVersions",
      "lambda:GetAccountSettings",
      "lambda:UpdateFunctionEventInvokeConfig",
      "lambda:GetFunctionEventInvokeConfig",
      "lambda:DeleteFunctionEventInvokeConfig",
      "lambda:PutFunctionEventInvokeConfig"
    ]
    resources = ["*"]
  }

  # CloudFront permissions
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateCachePolicy",
      "cloudfront:DeleteCachePolicy",
      "cloudfront:GetCachePolicy",
      "cloudfront:UpdateCachePolicy",
      "cloudfront:ListCachePolicies",
      "cloudfront:CreateOriginRequestPolicy",
      "cloudfront:DeleteOriginRequestPolicy",
      "cloudfront:GetOriginRequestPolicy",
      "cloudfront:UpdateOriginRequestPolicy",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:CreateFieldLevelEncryptionConfig",
      "cloudfront:DeleteFieldLevelEncryptionConfig",
      "cloudfront:GetFieldLevelEncryptionConfig",
      "cloudfront:UpdateFieldLevelEncryptionConfig",
      "cloudfront:ListFieldLevelEncryptionConfigs",
      "cloudfront:CreateFieldLevelEncryptionProfile",
      "cloudfront:DeleteFieldLevelEncryptionProfile",
      "cloudfront:GetFieldLevelEncryptionProfile",
      "cloudfront:UpdateFieldLevelEncryptionProfile",
      "cloudfront:ListFieldLevelEncryptionProfiles",
      "cloudfront:GetInvalidation",
      "cloudfront:CreateInvalidation",
      "cloudfront:ListInvalidations",
      "cloudfront:GetStreamingDistribution",
      "cloudfront:GetStreamingDistributionConfig",
      "cloudfront:ListStreamingDistributions"
    ]
    resources = ["*"]
  }

  # S3 permissions for CloudFront
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:ListBucket"
    ]
    resources = ["${local.s3_bucket_arn}"]
  }
}

resource "aws_iam_policy" "infrastructure" {
  name        = "${aws_iam_user.cd.name}-infrastructure"
  description = "Allow user to manage infrastructure resources (EC2, ECS, ELB, Lambda, CloudFront)."
  policy      = data.aws_iam_policy_document.infrastructure.json
}

resource "aws_iam_user_policy_attachment" "infrastructure" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.infrastructure.arn
}

#########################
# ALB/Load Balancer Policy #
#########################

data "aws_iam_policy_document" "alb" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb" {
  name        = "${aws_iam_user.cd.name}-alb"
  description = "Allow user to manage Application Load Balancers and Target Groups."
  policy      = data.aws_iam_policy_document.alb.json
}

resource "aws_iam_user_policy_attachment" "alb" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.alb.arn
}

#########################
# Auto Scaling Policy #
#########################

data "aws_iam_policy_document" "autoscaling" {
  # Application Auto Scaling permissions
  statement {
    effect = "Allow"
    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingActivities",
      "application-autoscaling:DescribeScalingPolicies",
      "application-autoscaling:DescribeScheduledActions",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:PutScheduledAction",
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeleteScheduledAction",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:SetDesiredCapacity",
      "application-autoscaling:DescribeScalingPolicies",
      "application-autoscaling:DescribeScalingActivities",
      "application-autoscaling:TagResource",
      "application-autoscaling:ListTagsForResource",
      "application-autoscaling:UntagResource"
    ]
    resources = ["*"]
  }

  # Auto Scaling Group permissions
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeScalingProcessTypes",
      "autoscaling:DescribeScheduledActions",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeTerminationPolicyTypes",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteTags",
      "autoscaling:AttachInstances",
      "autoscaling:DetachInstances",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:DetachLoadBalancers",
      "autoscaling:AttachLoadBalancerTargetGroups",
      "autoscaling:DetachLoadBalancerTargetGroups",
      "autoscaling:EnterStandby",
      "autoscaling:ExitStandby",
      "autoscaling:ResumeProcesses",
      "autoscaling:SuspendProcesses",
      "autoscaling:PutScheduledUpdateGroupAction",
      "autoscaling:DeleteScheduledAction",
      "autoscaling:PutLifecycleHook",
      "autoscaling:DeleteLifecycleHook",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:RecordLifecycleActionHeartbeat",
      "autoscaling:CompleteLifecycleAction"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "autoscaling" {
  name        = "${aws_iam_user.cd.name}-autoscaling"
  description = "Allow user to manage Auto Scaling Groups and Application Auto Scaling."
  policy      = data.aws_iam_policy_document.autoscaling.json
}

resource "aws_iam_user_policy_attachment" "autoscaling" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.autoscaling.arn
}

########################
# Ready thine database #
########################

data "aws_iam_policy_document" "rds" {
  statement {
    effect = "Allow"
    actions = [
      "rds:DescribeDBSubnetGroups",
      "rds:DescribeDBInstances",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:CreateDBInstance",
      "rds:DeleteDBInstance",
      "rds:ListTagsForResource",
      "rds:ModifyDBInstance",
      "rds:AddTagsToResource",
      # Backup and snapshot management
      "rds:DescribeDBSnapshots",
      "rds:CreateDBSnapshot",
      "rds:DeleteDBSnapshot",
      "rds:RestoreDBInstanceFromDBSnapshot",
      "rds:RestoreDBInstanceFromS3",
      "rds:DescribeDBInstanceAutomatedBackups",
      "rds:DeleteDBInstanceAutomatedBackup",
      "rds:RestoreDBInstanceFromAutomatedBackup",
      "rds:CreateDBParameterGroup",
      "rds:DeleteDBParameterGroup",
      "rds:ModifyDBParameterGroup",
      "rds:DescribeDBParameterGroups",
      "rds:DescribeDBParameters",
      # Parameter and option groups
      "rds:DescribeDBParameterGroups",
      "rds:DescribeDBOptionGroups",
      # Additional useful permissions
      "rds:DescribeDBEngineVersions",
      "rds:DescribeOrderableDBInstanceOptions",
      "rds:DescribeDBInstanceAutomatedBackups",
      "rds:DescribePendingMaintenanceActions"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "rds" {
  name        = "${aws_iam_user.cd.name}-rds"
  description = "Allow user to manage RDS resources."
  policy      = data.aws_iam_policy_document.rds.json
}

resource "aws_iam_user_policy_attachment" "rds" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.rds.arn
}

#########################
# Policy for ECR access #
#########################

data "aws_iam_policy_document" "ecr" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListTagsForResource",
      "ecr:ListImages",
      "ecr:PutRegistryPolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:TagResource",
      "ecr:GetRepositoryPolicy"
    ]
    resources = [
      "arn:aws:ecr:*:*:repository/web-app",
      "arn:aws:ecr:*:*:repository/web-proxy",
      "arn:aws:ecr:*:*:repository/hash-lambda",
      "arn:aws:ecr:*:*:repository/numpy-convert"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr" {
  name        = "${aws_iam_user.cd.name}-ecr"
  description = "Allow user to push and pull images to/from specific ECR repositories."
  policy      = data.aws_iam_policy_document.ecr.json
}

resource "aws_iam_user_policy_attachment" "ecr" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.ecr.arn
}

#####################################
# Policy for CloudFront CDN access  #
# Including s3 bucket access        #
#####################################

data "aws_iam_policy_document" "cloudfront" {
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateCachePolicy",
      "cloudfront:DeleteCachePolicy",
      "cloudfront:GetCachePolicy",
      "cloudfront:UpdateCachePolicy",
      "cloudfront:ListCachePolicies",
      "cloudfront:CreateOriginRequestPolicy",
      "cloudfront:DeleteOriginRequestPolicy",
      "cloudfront:GetOriginRequestPolicy",
      "cloudfront:UpdateOriginRequestPolicy",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:CreateFieldLevelEncryptionConfig",
      "cloudfront:DeleteFieldLevelEncryptionConfig",
      "cloudfront:GetFieldLevelEncryptionConfig",
      "cloudfront:UpdateFieldLevelEncryptionConfig",
      "cloudfront:ListFieldLevelEncryptionConfigs",
      "cloudfront:CreateFieldLevelEncryptionProfile",
      "cloudfront:DeleteFieldLevelEncryptionProfile",
      "cloudfront:GetFieldLevelEncryptionProfile",
      "cloudfront:UpdateFieldLevelEncryptionProfile",
      "cloudfront:ListFieldLevelEncryptionProfiles",
      "cloudfront:GetInvalidation",
      "cloudfront:CreateInvalidation",
      "cloudfront:ListInvalidations",
      "cloudfront:GetStreamingDistribution",
      "cloudfront:GetStreamingDistributionConfig",
      "cloudfront:ListStreamingDistributions"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:ListBucket"
    ]
    resources = ["${local.s3_bucket_arn}"]
  }
}

resource "aws_iam_policy" "cloudfront" {
  name        = "${aws_iam_user.cd.name}-cloudfront"
  description = "Allow user to manage CloudFront CDN distributions and related resources."
  policy      = data.aws_iam_policy_document.cloudfront.json
}

resource "aws_iam_user_policy_attachment" "cloudfront" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.cloudfront.arn
}

#########################
# IAM Management Policy #
#########################

data "aws_iam_policy_document" "iam_management" {
  statement {
    effect = "Allow"
    actions = [
      "iam:ListInstanceProfilesForRole",
      "iam:ListAttachedRolePolicies",
      "iam:DeleteRole",
      "iam:ListPolicyVersions",
      "iam:DeletePolicy",
      "iam:DetachRolePolicy",
      "iam:ListRolePolicies",
      "iam:GetRole",
      "iam:GetPolicyVersion",
      "iam:GetPolicy",
      "iam:CreateRole",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:AttachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:PassRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRoleDescription",
      "iam:UntagPolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:UntagRole",
      "iam:ListRoleTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "iam_management" {
  name        = "${aws_iam_user.cd.name}-iam-management"
  description = "Allow user to manage IAM roles and policies."
  policy      = data.aws_iam_policy_document.iam_management.json
}

resource "aws_iam_user_policy_attachment" "iam_management" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.iam_management.arn
}

################################
# Policy for CloudWatch access #
################################

data "aws_iam_policy_document" "logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:CreateLogGroup",
      "logs:TagResource",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "logs" {
  name        = "${aws_iam_user.cd.name}-logs"
  description = "Allow user to manage CloudWatch resources."
  policy      = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_user_policy_attachment" "logs" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.logs.arn
}

################################
# Policy for Route53 and ACM   #
# Read-only access for setup   #
################################

data "aws_iam_policy_document" "route53_acm_read" {
  # Route53 read permissions (needed for discovery)
  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:GetChange",
      "route53:ListTagsForResource",
      "route53:ListHostedZonesByName"
    ]
    resources = ["*"]
  }

  # Route53 write permissions (scoped to magicalapis.net hosted zone only)
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChangeDetails"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  # ACM read permissions
  statement {
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "acm:GetCertificate"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "route53_acm_read" {
  name        = "${aws_iam_user.cd.name}-route53-acm-read"
  description = "Allow user to read Route53 hosted zones and ACM certificates, and create DNS records for setup validation."
  policy      = data.aws_iam_policy_document.route53_acm_read.json
}

resource "aws_iam_user_policy_attachment" "route53_acm_read" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.route53_acm_read.arn
}
