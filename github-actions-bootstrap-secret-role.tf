//TODO Register Github action as an OIDC connect provider with aws STS
resource "aws_iam_openid_connect_provider" "github-actions" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
}


//TODO - Run manually one time outside the Github action, avoid looping on trust boundary dependency
// Configuring an IAM role for bootstrap secret with trusted "github-actions-infrastructure" repository assuming
resource "aws_iam_role" "github-actions-bootstrap-secret-role" {
  name = "github-actions-bootstrap-secret-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github-actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:anhvt13@42229955/github-actions-infrastructure@1375902132:ref:refs/heads/main",
              "repo:anhvt13@42229955/github-actions-infrastructure@1375902132:environment:prod"
            ]
          }
        }
      }
    ]
  })
}

// Explicit least privilege policies on bootstrap secret role policy
resource "aws_iam_role_policy" "github-actions-bootstrap-secret-policy" {
  name = "github-actions-bootstrap-secret-policy"
  role = aws_iam_role.github-actions-bootstrap-secret-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ========================
      # Least privilege on Secret Manager resources
      # ========================
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-southeast-1:249899229305:secret:capstone/bff/tls",
          "arn:aws:secretsmanager:ap-southeast-1:249899229305:secret:capstone/driver/tls",
          "arn:aws:secretsmanager:ap-southeast-1:249899229305:secret:capstone/bff/oauth2"
        ]
      },

      # ============================================================
      # S3 - Terraform OIDC state bucket
      # ============================================================
      {
        Sid    = "TerraformStateBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::capstone-terraform-state-249899229305-ap-southeast-1-an"
      },
      {
        Sid    = "TerraformStateObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::capstone-terraform-state-249899229305-ap-southeast-1-an/oidc/terraform.tfstate"
      },
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::capstone-terraform-state-249899229305-ap-southeast-1-an/oidc/terraform.tfstate.tflock"
      },

      # ============================================================
      # IAM Manage Role
      # ============================================================
      {
        Sid    = "ManageOIDCRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRolePolicy",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:DeleteRolePolicy",
          "iam:ListInstanceProfilesForRole",
          "iam:DeleteRole",
          "iam:CreateRole",
          "iam:PutRolePolicy"
        ]
        Resource = [
          "arn:aws:iam::249899229305:role/github-actions-bootstrap-secret-role",
          "arn:aws:iam::249899229305:role/github-actions-infrastructure-deployment-role"
        ]
      },

      # ============================================================
      # IAM Manage Provider
      # ============================================================
      {
        Sid    = "ManageOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider"
        ]
        Resource = [
          "arn:aws:iam::249899229305:oidc-provider/token.actions.githubusercontent.com"
        ]
      }
    ]
  })
}


