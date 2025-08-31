# Ansible Playbooks for 3-Tier Java Application Deployment

This directory contains Ansible playbooks to automate the deployment of a Java web application on AWS using a 3-tier architecture.

## Setup Playbooks

### 1. Bootstrap (Minimal Setup)
For initial setup when you don't have Ansible installed on the bastion host:
```bash
# Run this first if Ansible is not installed on bastion
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml
```

### 2. Complete Environment Setup
To set up a complete Ansible environment on the bastion host:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/setup_environment.yml
```

## Application Deployment Playbooks

### Individual Playbooks
You can run each component separately:

```bash
# Test connectivity
ansible-playbook playbooks/site.yml --tags ping

# Setup database
ansible-playbook playbooks/setup_database.yml

# Install Tomcat
ansible-playbook playbooks/install_tomcat.yml

# Build and upload application
ansible-playbook playbooks/build_and_upload_war.yml

# Deploy application
ansible-playbook playbooks/deploy_from_s3.yml

# Configure Nginx
ansible-playbook playbooks/nginx_reverse_proxy.yml
```

### Complete Deployment
Run all playbooks in sequence:
```bash
# Deploy everything
ansible-playbook playbooks/site.yml

# Or include environment setup
ansible-playbook playbooks/site.yml --tags setup_env
```

## Prerequisites

1. **AWS Resources**: Ensure your AWS infrastructure is ready:
   - VPC with public/private subnets
   - EC2 instances (bastion, web servers, app servers)
   - RDS MySQL database
   - S3 bucket for artifacts
   - Security groups configured

2. **Local Machine Requirements**:
   - SSH key pair (`devops-p1-keypair.pem`)
   - Ansible installed locally to manage remote hosts
   - AWS CLI configured (for initial setup)
   - Network access to bastion host

3. **Configure Variables**: 
   - Update IP addresses in `inventory/hosts.ini`
   - Review and modify variables in `group_vars/`:
     - `all.yml` - Global variables
     - `webservers.yml` - Nginx configuration
     - `appservers.yml` - Tomcat configuration  
     - `bastion.yml` - Build and deployment settings
   - Create encrypted vault: `ansible-vault create group_vars/vault.yml`
   - Use `group_vars/vault.yml.example` as template for sensitive data

## Quick Start

1. **First time setup**:
```bash
# Copy your SSH key to the correct location
cp /path/to/your/key.pem ../.ssh/devops-p1-keypair.pem
chmod 400 ../.ssh/devops-p1-keypair.pem

# Test connectivity to your AWS instances
ansible all -m ping

# Setup Ansible environment on bastion host (if needed)
ansible-playbook playbooks/setup_environment.yml
```

2. **Deploy application**:
```bash
# Full deployment
ansible-playbook playbooks/site.yml

# With encrypted vault
ansible-playbook playbooks/site.yml --ask-vault-pass

# With vault password file
ansible-playbook playbooks/site.yml --vault-password-file ~/.vault_pass
```

## Playbook Details

- **`bootstrap.yml`**: Minimal setup using raw commands for initial bastion setup
- **`setup_environment.yml`**: Complete Ansible and AWS CLI setup on bastion host
- **`setup_database.yml`**: Database schema and test data creation
- **`install_tomcat.yml`**: Java and Tomcat installation on app servers
- **`build_and_upload_war.yml`**: Build application and upload to S3
- **`deploy_from_s3.yml`**: Download and deploy application to Tomcat
- **`nginx_reverse_proxy.yml`**: Load balancer configuration on web servers
- **`site.yml`**: Main orchestration playbook

## Variable Organization

Variables are organized into separate files for better maintainability:

### `group_vars/all.yml`
- Global variables used across all hosts
- Common packages, timeouts, application settings
- References to vault variables for sensitive data

### `group_vars/webservers.yml`
- Nginx-specific configuration
- Load balancer settings
- Performance tuning

### `group_vars/appservers.yml`
- Tomcat configuration
- JVM settings and performance tuning
- Service management

### `group_vars/bastion.yml`
- Build and deployment settings
- Repository and artifact management

### `group_vars/vault.yml` (encrypted)
- Sensitive data: passwords, API keys, tokens
- Create with: `ansible-vault create group_vars/vault.yml`
- Use template: `group_vars/vault.yml.example`

## Security Notes

⚠️ **Important**: 
- AWS credentials are hardcoded in playbooks (for demo only)
- Use IAM roles and Ansible Vault for production
- Database passwords should be encrypted
- Consider using AWS Secrets Manager

## Troubleshooting

1. **SSH Issues**:
   - Check key permissions: `chmod 400 ~/.ssh/devops-p1-keypair.pem`
   - Verify key path in `ansible.cfg`

2. **AWS Issues**:
   - Ensure AWS credentials are configured: `aws configure`
   - Check security groups allow required ports

3. **Ansible Issues**:
   - Run with verbose output: `ansible-playbook -vvv`
   - Check logs: `tail -f ansible.log`

## Architecture

```
Internet → ALB → Nginx (Web Tier) → Tomcat (App Tier) → RDS MySQL (DB Tier)
                    ↑                        ↑
                Bastion Host           S3 (Artifacts)
```

- **Web Tier**: Nginx reverse proxy for load balancing
- **App Tier**: Tomcat servers running Java application
- **DB Tier**: RDS MySQL database
- **Build**: Maven build on bastion, artifacts stored in S3
