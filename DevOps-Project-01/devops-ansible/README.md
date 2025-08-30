# DevOps Project Ansible Configuration

## Structure
- `inventories/` - Server inventory and variables
- `playbooks/` - Ansible playbooks
- `roles/` - Reusable roles
- `vars/` - Additional variables

## Quick Start
1. Test connectivity: `ansible all -m ping`
2. Update RDS: `./update-rds-endpoint.sh`
3. Deploy stack: `ansible-playbook playbooks/deploy-complete-stack.yml`

## Files
- `ansible.cfg` - Main configuration
- `inventories/hosts` - Server inventory
- `playbooks/test-connectivity.yml` - Basic connectivity test
- `playbooks/install-nginx.yml` - Web server setup
- `playbooks/install-tomcat.yml` - App server setup
- `update-rds-endpoint.sh` - Helper script for RDS config
