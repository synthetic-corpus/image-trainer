# image-trainer
This project will use ML to classifly a huge source of character portaits. It relies on entirely on python with Flask, Pillow, Scikit learn and few other libraries. It is deployed with Terraform.

# How it works
This project is designed to work with .jpeg, .jpg, and .png files only. It uses a prepocessing technique to ready the files.

A user must manually upload any number of files into an s3 bucket (see setup section) in a folder called 'upload'. Then the project will run two different Lambdas. The first Lambdas gets a hash value of the file in upload and moves into a sources folder. It also writes a row in the database. Then the original upload file is deleted to save space. Next, another Lambda reads the file in the bucket's sources folder. It creates a new Numpy file from that image an places it in the numpy folder.

From there, the CDN can read from sources to display the files for labeling. The numpy files names will match the hash can can later be used for Machine Learning.

# Set up and Disclaimer

This project has all the Terraform code needed to deploy this project, but some manual set up is still required and user will need to configure various variables.

Additionally *everything here costs money* to deploy to AWS, so use at your own risk and at your cost. I am not responible for any costs you incur should you use this code. :-)

## Set Up - Manual Set up

Is intended to be set up with Terraform. Users will need prepare the usual s3 buckets and a dynomodb table for Terraform.

Additionally, users will need to *manually create* an s3 bucket and keep track of its name. It must be referenced correctly in deploy/existing.tf either by hard coding it there, intepereting it from git hub action, or other means etc.

User will also need a domain set up with AWS via Route 

## Set up - setup/main.tf

This section is intended to be deployed with Terraform *locally* via an admin account. It will create a user account and access key for use in deploy/main.tf. It will also create AWS container registries used for the creation of lambdas and ecs tasks used in the deploy folder.

The AWS Key is a hidden output see terrform CLI commands to learn how to view it. :-)

## Set up - deploy/main.tf

This is the Terraform folder that will deploy most of the project. It is intended to be deployed through github actions, but can be deployed through CLI as well. Either way, it requires several variables to be set either locally or through hard coding, a git variable etc.

More details about those variables can be found in deploy/readme.md


# Notes on the Database

The database will first look for a AWS snapshots before loading a fresh database.

The Database is *designed* to trigger a Lambda that preps a single database table after it is ready. However that Lambda does not usually trigger due to the complexity of timing with Eventbridge. Go into the console and run the lambda set up in deploy/init-db-lambda.tf as a test. It is expected to set up the database table.

If the database is loaded from a snapshot, running the Lambda will not be needed.

# How to Train

Once deployed, the project will be accesible through a web interface at the domain. Go through the photos labeling them as male of female. Delete any that are not suitable with delete button. (This is a soft delete in the database).

Then remote into the larger of the two ec2 instances and git clone this related repository. Tools here will allow a user to try out three different models from the CLI.