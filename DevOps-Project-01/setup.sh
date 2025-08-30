#!/bin/bash

# Basic Setup Script for Bastion Host
# Installs Ansible, AWS CLI, and configures SSH

echo "==================================="
echo "Basic Setup: Ansible + AWS CLI + SSH"
echo "==================================="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install basic packages
echo "Installing basic packages..."
sudo yum install python3 python3-pip git wget unzip curl -y

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install Ansible
echo "Installing Ansible..."
pip3 install --user ansible boto3 botocore

# Add Python bin to PATH
echo "Adding Python bin to PATH..."
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
export PATH=$PATH:~/.local/bin

# Install AWS Ansible collections
echo "Installing AWS Ansible collections..."
~/.local/bin/ansible-galaxy collection install amazon.aws

# Setup SSH directory
echo "Setting up SSH configuration..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Verify installations
echo "Verifying installations..."
echo "AWS CLI version:"
aws --version

echo "Ansible version:"
~/.local/bin/ansible --version

echo "Python version:"
python3 --version

echo "==================================="
echo "Basic Setup Complete!"
echo "==================================="
echo ""
echo "Next Steps:"
echo "1. Configure AWS CLI: aws configure"
echo "2. Copy your SSH key to ~/.ssh/devops-p1-keypair.pem"
echo "3. Set key permissions: chmod 400 ~/.ssh/devops-p1-keypair.pem"
echo "4. Run the Ansible configuration script"
echo ""
echo "To configure AWS CLI now, run: aws configure"
echo "You'll need:"
echo "- AWS Access Key ID"
echo "- AWS Secret Access Key"
echo "- Default region: us-east-1"
echo "- Default output format: json"
echo "==================================="