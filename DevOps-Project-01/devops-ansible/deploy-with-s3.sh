#!/bin/bash
echo "Setting up S3 bucket..."
ansible-playbook playbooks/setup-s3-bucket.yml
source s3-config.env
export S3_BUCKET_NAME S3_REGION
echo "Deploying complete stack..."
ansible-playbook playbooks/deploy-complete-stack.yml
echo "Deployment complete!"
