# image-trainer

This project uses ML to classify a large collection of character portraits. It is written entirely in Python and uses Flask, Pillow, Scikit-learn, and a few other libraries. Deployment is handled with Terraform.

---

## How it works

This project is designed to work with `.jpeg`, `.jpg`, and `.png` files only. It applies a preprocessing technique to prepare the files.

1. A user must manually upload any number of files into an S3 bucket (see setup section) inside a folder called `upload`.  
2. The project runs two different Lambdas:  
   - The first Lambda generates a hash value for each file in `upload`, moves it into a `sources` folder, writes a row into the database, and deletes the original file to save space.  
   - The second Lambda reads the file from the bucket’s `sources` folder, creates a new Numpy file from the image, and places it in the `numpy` folder.  

From there, the CDN can read from `sources` to display the files for labeling. The Numpy filenames match the hash values and can later be used for Machine Learning.

---

## Setup and Disclaimer

This project includes all the Terraform code needed to deploy, but some manual setup is still required. You will also need to configure various variables.

⚠️ **Important:** *Everything here costs money* to deploy to AWS. Use at your own risk and at your own cost. I am not responsible for any charges you may incur.

---

### Setup — Manual Steps

Although this project is intended to be deployed with Terraform, you will still need to prepare:  
- the usual S3 buckets, and  
- a DynamoDB table for Terraform state management.  

Additionally, you must *manually create* an S3 bucket and record its name. It must be referenced correctly in `deploy/existing.tf` — either by hard-coding it, retrieving it from GitHub Actions, or other means.  

You will also need a domain set up in AWS Route 53.  

---

### Setup — `setup/main.tf`

This section should be deployed with Terraform **locally** via an admin account. It will:  
- create a user account and access key for use in `deploy/main.tf`, and  
- create AWS container registries for Lambda functions and ECS tasks defined in the `deploy` folder.  

The AWS key is a hidden Terraform output — see the Terraform CLI documentation to learn how to view it.  

---

### Setup — `deploy/main.tf`

This Terraform folder deploys most of the project. It is intended to run through GitHub Actions, but it can also be deployed via the CLI. In either case, it requires several variables to be set (locally, through hard-coding, or via GitHub variables).  

More details about required variables can be found in `deploy/readme.md`.  

---

## Notes on the Database

- On startup, the database will first check for AWS snapshots before creating a fresh database.  
- The database is *designed* to trigger a Lambda that prepares a single database table once it is ready. However, this Lambda often does not trigger automatically due to timing complexities with EventBridge.  
  - To fix this, go into the AWS console and manually run the Lambda defined in `deploy/init-db-lambda.tf`. It should initialize the database table.  
- If the database is restored from a snapshot, running this Lambda will not be necessary.  

---

## How to Train

Once deployed, the project will be accessible via the web interface at the configured domain.  

- Go through the photos, labeling them as **male** or **female**.  
- Delete unsuitable images using the delete button (note: this performs a soft delete in the database).  

To begin training:  
1. Remote into the larger of the two EC2 instances.  
2. Clone the related repository.  
3. Use the included tools to experiment with three different models directly from the CLI.  
