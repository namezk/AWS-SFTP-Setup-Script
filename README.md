# AWS-SFTP-Setup-Script


Amazon Web Services now offers SFTP as a service; To use it, you need to setup a few resources on the back end; This script automates that for you.


## Prerequisites

- Working awscli
- Permissions within the AWS account
- SSH key-pair

## Details

The script walks you through creating the resources needed to setup an AWS Transfer server instance. 

### Resources Created

- An S3 bucket
- An IAM role used by the SFTP server to access the bucket
- An IAM role used by the SFTP server to log activity to CloudWatch Logs
- The actual Transfer server instance
- An SFTP user on the created server
