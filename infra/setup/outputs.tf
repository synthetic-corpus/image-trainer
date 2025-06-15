output "cd_user_access_key_id" {
  description = "AWS key ID for CD user"
  value       = aws_iam_access_key.cd.id
}

output "cd_user_access_key_secret" {
  description = "Access Key for our super secret CD user" #
  value       = aws_iam_access_key.cd.secret
  sensitive   = true # outputs in clear text only when specified!
}
