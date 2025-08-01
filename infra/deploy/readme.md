# Variables.tf
Before running a deployment in this folder a number of variables need to be accounted for, either through something like github secrets/varibles, local environment variables, or hard coding. Here is an explanation of each one. Most will be found in variables.tf, existing.tf, and usually access through locals in main.tf

# Variables.tf
Most of the variables here are self explanatory via their description. The prefix variable is used in several other places to name resources. The same story is with the project name.

the aws_region is likely best hardcoded, and use which ever region you want.

The s3_bucket_name variable is the name of the bucket that that is *not set up* with Terraform, and must be named manually. The default value is for example only.

The tf_state_bucket and tf_state_lock table must be changed prior to running this code. Those are resources assumed to have been set up independly of terraform.

The ECR variables will need to be replaced the paths to ECR repositories created with setup/main.tf. In the case of github actions deployment, these can be set with github secrets.

The domain name variable must be changed from its default variable.

# Variables in existing.tf

These variables reflect the names of resouces that are not controlled by deploy/main.tf. They are set up manually, by setup/main.tf, or are derived by running a function against some other existing value. Most of these will likely not need to be changed.

# Locals in Main.tf
The Variables here are intended to be set from github actions. Important exception is ami_image_id and ami_image_id_big. These strings are Amazon AMI that are region specific. Both the values in this code are publically available, but use at your own risk.

# Values in Docker-Compose.yaml
If you want to use Github Secrest or environment variables on a local machine, this where to go. If a value begins with TF_VAR than it is something that will be imported to terraform. Export the variables by referencing the same name.

TF_VAR_use_snapshot and TF_VAR_snapshot_identifier are only relevent if you are using github actions the deployment file .github/workflows. If you are not intending to use those, ignore these.

The AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY should either be local admin credentials, or the result of of running setup/main.tf You can also put any AWS credentials here if you wanted to. That account would simply need all the permissions to deploy all the resources in the deploy folder.

Note, the default region in this file is hardcoded!