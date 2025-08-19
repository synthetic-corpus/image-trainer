# Variables.tf

Before running a deployment in this folder, a number of variables need to be set. This can be done through GitHub secrets/variables, local environment variables, or hard-coding them directly. Below is an explanation of each one. Most of these can be found in `variables.tf`, `existing.tf`, and are usually accessed through `locals` in `main.tf`.

---

## Variables in variables.tf

Most of the variables here are self-explanatory via their descriptions.  
- The `prefix` variable is used in several places to name resources, as is the `project_name` variable.  
- The `aws_region` is likely best hardcoded — use whichever region you prefer.  
- The `s3_bucket_name` variable is the name of a bucket that is *not set up* with Terraform and must be created manually. The default value is provided only as an example.  
- The `tf_state_bucket` and `tf_state_lock_table` must be updated before running this code. These are assumed to have been set up independently of Terraform.  
- The ECR variables must be replaced with paths to ECR repositories created with `setup/main.tf`. For GitHub Actions deployments, these can be set using GitHub secrets.  
- The `domain_name` variable must be changed from its default value.  

---

## Variables in existing.tf

These variables reflect the names of resources that are not controlled by `deploy/main.tf`. They are either:  
- set up manually,  
- created by `setup/main.tf`, or  
- derived by running a function against an existing value.  

Most of these will not need to be changed.  

---

## Locals in main.tf

The variables here are generally intended to be set by GitHub Actions.  

**Important exception:**  
- `ami_image_id` and `ami_image_id_big` are Amazon AMI IDs that are region-specific.  
- The values provided in this code are publicly available, but use them at your own risk.  

---

## Values in docker-compose.yaml

If you want to use GitHub secrets or environment variables on a local machine, this is where to configure them.  

- Any value that begins with `TF_VAR` will be imported into Terraform. E_
