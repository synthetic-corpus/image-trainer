# Deployment Scripts

This directory contains scripts for managing the infrastructure deployment.

## Scripts

### `invoke-init-db.sh`
Manually invokes the database initialization Lambda function.

**Usage:**
```bash
./invoke-init-db.sh [workspace]
```

**Examples:**
```bash
# Invoke for staging workspace (default)
./invoke-init-db.sh

# Invoke for production workspace
./invoke-init-db.sh prod
```

**What it does:**
1. Selects the specified Terraform workspace
2. Gets the Lambda function name from Terraform outputs
3. Invokes the database initialization Lambda function
4. Displays the response and recent logs

### `determine-db-approach.sh`
Determines whether to use a database snapshot or create a fresh database.

### `deploy-database.sh`
Deploys the database infrastructure.

### `find-latest-snapshot.sh`
Finds the latest available database snapshot.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed and configured
- Access to the AWS account and region

## Notes

- All scripts should be run from the `infra/deploy` directory
- The `invoke-init-db.sh` script is also automatically run during the GitHub Actions deployment pipeline 