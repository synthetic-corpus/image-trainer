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
      "ec2:DescribeVpcs",
      "ec2:CreateTags",
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
    ]
    resources = ["*"]
  }

  # ELB/ALB permissions
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
      "elasticloadbalancing:ModifyTargetGroup"
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
      "rds:AddTagsToResource"
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
      "arn:aws:ecr:*:*:repository/hash-lambda"
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
      "iam:AttachRolePolicy",
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
