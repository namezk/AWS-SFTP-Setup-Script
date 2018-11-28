#!/bin/bash
if [ ${#@} -ne 0 ] && [ "${@#"--help"}" = "" ]; then
  printf -- '
  This simple script helps you setup an AWS Transfer server for SFTP, the easy way, just follow the prompts.
  			 \n';
  exit 0;
fi;
printf -- '
https://github.com/namezk/AWS-SFTP-Setup-Script
This script helps you setup an AWS Transfer for SFTP the easy way, follow the prompts to create all the AWS resources necessary.
Note: The script requires an up-to-date awscli with the right permissions.\n\n';
read -p "Please specify the name of the awscli profile you'd like to use:" profile
printf '\n'
read -p "First, we'll create an S3 bucket, please enter a name for the bucket: " bucketname
printf -- 'Creating bucket...\n';
aws s3 mb s3://$bucketname
printf '\n'
printf -- 'Now creating IAM role and associated policies...\n';
# Save the policy to a temp file
cat >transfer-trust-relationship.json <<"EOF"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
EOF
# Create the IAM role for s3 access
aws iam create-role --role-name s3-transfer --assume-role-policy-document file://transfer-trust-relationship.json --description "Used by SFTP Transfer to access S3 resources" --output text --profile $profile
printf '\n'
# Save the policy to a temp file
policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::$bucketname"
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::$bucketname/*"
            ]
        }
    ]
}
EOF
)
echo $policy > s3-transfer-role-policy.json
# Attach the policy to the role
aws iam put-role-policy --role-name s3-transfer --policy-name s3-transfer-role-policy --policy-document file://s3-transfer-role-policy.json --output text --profile $profile
printf '\n'
# Remove the temp file
rm -f s3-transfer-role-policy.json
### Repeat the same steps for the logging role
# Create the IAM role for CloudWatch Logs access
aws iam create-role --role-name cw-transfer --assume-role-policy-document file://transfer-trust-relationship.json --description "Used by SFTP Transfer to access CloudWatch Logs" --output text --profile $profile
# Get the arns for roles
loggingrole=$(aws iam list-roles --query 'Roles[?RoleName==`cw-transfer`].Arn' --output text)
s3role=$(aws iam list-roles --query 'Roles[?RoleName==`s3-transfer`].Arn' --output text)
printf '\n'
# Save the policy to a temp file
policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
echo $policy > cw-transfer-role-policy.json
# Attach the policy to the role
aws iam put-role-policy --role-name cw-transfer --policy-name cw-transfer-role-policy --policy-document file://cw-transfer-role-policy.json --output text --profile $profile
printf '\n'
# Create the server
printf -- '
Roles and policies created, now creating Transfer server...\n';
serverid=$(aws transfer create-server --identity-provider-type SERVICE_MANAGED --logging-role $loggingrole --output text)
region=$(aws configure get region)
endpoint=$serverid.server.transfer.$region.amazonaws.com
printf '\n'
echo "Transfer server created, the server ID is: "$serverid 
echo "Reachable at this endpoint: " $endpoint 
printf '\n'
# Create a user
printf '\n'
printf -- '
With the bucket, roles, policies and the server creation complete, let us create a user on our new server.
Before proceeding, you should already have a public/private key pair.\n';
read -p "Please enter a username for the sftp user: " sftpusername
read -p "Please enter/paste the public key for this user (This needs to be an ssh publickey starting with "ssh-rsa"): " publickey
echo $publickey > public.key
printf '\n'
printf -- 'Creating user...\n';
aws transfer create-user --user-name $sftpusername --home-directory /$bucketname --role $s3role --ssh-public-key-body file://public.key --server-id $serverid --output text --profile $profile
printf '\n'
printf '\n'
printf 'All done!'
printf '\n'
echo 'The following resources were created in' $region':'
echo '- An S3 bucket: ' $bucketname
echo '- An IAM role used by the SFTP server to access the bucket: ' $s3role
echo '- An IAM role used by the SFTP server to log activity to CloudWatch Logs: ' $loggingrole
echo '- A Transfer server: ' $serverid
echo '- An SFTP user: ' $sftpusername
echo ''
echo 'All SFTP activity logs will be located in CloudWach Logs under /aws/transfer/'$serverid
echo ''
echo ''
https://github.com/namezk/AWS-SFTP-Setup-Script
echo ''
# Remove the temp files
rm -f cw-transfer-role-policy.json
rm -f transfer-trust-relationship.json
rm -f publickey.pub
