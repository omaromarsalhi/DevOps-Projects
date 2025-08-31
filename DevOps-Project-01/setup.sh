#!/bin/bash

# Fixed Setup Script for Amazon Linux 2023
# Installs Ansible, AWS CLI, and configures SSH

echo "==================================="
echo "Fixed Setup: Ansible + AWS CLI + SSH"
echo "==================================="

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install basic packages (using dnf for Amazon Linux 2023)
echo "Installing basic packages..."
sudo dnf install -y python3 python3-pip git wget unzip curl

# Alternative pip installation if dnf version doesn't work
if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found via dnf, trying alternative installation..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user
    rm get-pip.py
    export PATH=$PATH:~/.local/bin
fi

# Verify pip3 installation
echo "Verifying pip3 installation..."
if command -v pip3 &> /dev/null; then
    echo "pip3 found at: $(which pip3)"
    pip3 --version
elif python3 -m pip --version &> /dev/null; then
    echo "Using python3 -m pip instead of pip3"
    alias pip3='python3 -m pip'
else
    echo "ERROR: Cannot find working pip installation"
    exit 1
fi

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Add Python bin to PATH first
echo "Adding Python bin to PATH..."
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
export PATH=$PATH:~/.local/bin


# Install Ansible
echo "Installing Ansible..."
if command -v pip3 &> /dev/null; then
    pip3 install --user ansible
elif python3 -m pip --version &> /dev/null; then
    python3 -m pip install --user ansible
else
    echo "ERROR: Cannot install Ansible - no working pip found"
    exit 1
fi

# Install boto3 and botocore for Ansible AWS modules
echo "Installing boto3 and botocore for Ansible AWS modules..."
if command -v pip3 &> /dev/null; then
    pip3 install --user boto3 botocore
elif python3 -m pip --version &> /dev/null; then
    python3 -m pip install --user boto3 botocore
else
    echo "ERROR: Cannot install boto3/botocore - no working pip found"
    exit 1
fi

# Wait a moment for installation to complete
sleep 2

# Verify Ansible installation
echo "Verifying Ansible installation..."
ls -la ~/.local/bin/ | grep ansible || echo "No ansible files found in ~/.local/bin/"

# Try to find ansible installation
if [ -f ~/.local/bin/ansible ]; then
    echo "Ansible found at ~/.local/bin/ansible"
elif command -v ansible &> /dev/null; then
    echo "Ansible found at: $(which ansible)"
else
    echo "Searching for ansible installation..."
    find ~/.local -name "ansible*" 2>/dev/null || echo "No ansible installation found"
fi

# Install AWS Ansible collections
echo "Installing AWS Ansible collections..."
if [ -f ~/.local/bin/ansible-galaxy ]; then
    ~/.local/bin/ansible-galaxy collection install amazon.aws
elif command -v ansible-galaxy &> /dev/null; then
    ansible-galaxy collection install amazon.aws
else
    echo "Warning: ansible-galaxy not found. You'll need to install collections manually later:"
    echo "Run: ansible-galaxy collection install amazon.aws"
fi

# Setup SSH directory
echo "Setting up SSH configuration..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Verify installations
echo "==================================="
echo "FINAL VERIFICATION"
echo "==================================="
echo "AWS CLI version:"
aws --version

echo "Python version:"
python3 --version

echo "pip3 status:"
if command -v pip3 &> /dev/null; then
    pip3 --version
elif python3 -m pip --version &> /dev/null; then
    echo "pip available via: python3 -m pip"
    python3 -m pip --version
else
    echo "pip not available"
fi

echo "Ansible status:"
if [ -f ~/.local/bin/ansible ]; then
    echo "Ansible found at ~/.local/bin/ansible"
    ~/.local/bin/ansible --version | head -1
elif command -v ansible &> /dev/null; then
    echo "Ansible found at: $(which ansible)"
    ansible --version | head -1
else
    echo "Ansible not found"
    echo "Try running these commands manually:"
    echo "  source ~/.bashrc"
    echo "  pip3 install --user ansible boto3 botocore"
    echo "  or: python3 -m pip install --user ansible boto3 botocore"
fi

echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo ""
echo "IMPORTANT: Run this command to refresh your PATH:"
echo "source ~/.bashrc"
echo ""
echo "Then test Ansible:"
echo "ansible --version"
echo "# or if not found:"
echo "~/.local/bin/ansible --version"
echo ""
echo "If Ansible still doesn't work, run manually:"
echo "pip3 install --user ansible boto3 botocore"
echo "# or:"
echo "python3 -m pip install --user ansible boto3 botocore"
echo ""
echo "Next Steps:"
echo "1. Run: source ~/.bashrc"
echo "2. Test: ansible --version"
echo "3. Configure AWS CLI: aws configure"
echo "4. Copy your SSH key to ~/.ssh/devops-p1-keypair.pem"
echo "5. Set key permissions: chmod 400 ~/.ssh/devops-p1-keypair.pem"
echo ""
echo "AWS CLI Configuration needs:"
echo "- AWS Access Key ID"
echo "- AWS Secret Access Key"  
echo "- Default region: us-east-1"
echo "- Default output format: json"
echo "=================================="