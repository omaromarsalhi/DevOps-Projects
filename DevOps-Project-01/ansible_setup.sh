#!/bin/bash

# Complete Ansible Setup Script
# Run this script in an empty /devops-ansible/ directory
# This creates the entire Ansible project structure from scratch

echo "==================================="
echo "Complete Ansible Project Setup"
echo "==================================="

# Check if we're in the right directory
if [[ ! "$PWD" == *"devops-ansible"* ]]; then
    echo "Warning: You should run this script from the devops-ansible directory"
    echo "Current directory: $PWD"
    read -p "Continue anyway? (y/n): " continue_choice
    if [[ $continue_choice != "y" && $continue_choice != "Y" ]]; then
        exit 1
    fi
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p {inventories/group_vars,playbooks,roles/{nginx,tomcat,common}/tasks,vars}

# Create ansible.cfg
echo "Creating ansible.cfg..."
cat > ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventories/hosts
private_key_file = ~/.ssh/devops-p1-keypair.pem
remote_user = ec2-user
timeout = 30
retry_files_enabled = False
forks = 10
pipelining = True
strategy = linear
log_path = ~/.ansible.log
display_skipped_hosts = False
display_ok_hosts = True
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
pipelining = True
retries = 3
timeout = 30
connect_timeout = 60
command_timeout = 120

[privilege_escalation]
become_plugins = sudo, su, pbrun, pfexec, doas, dzdo, ksu, runas, machinectl
EOF

# Create inventory file
echo "Creating inventory file..."
cat > inventories/hosts << 'EOF'
[webservers]
web-server-1 ansible_host=10.0.1.20 ansible_user=ec2-user
web-server-2 ansible_host=10.0.4.190 ansible_user=ec2-user

[appservers]
app-server-1 ansible_host=10.0.2.29 ansible_user=ec2-user
app-server-2 ansible_host=10.0.5.17 ansible_user=ec2-user

[privateservers:children]
webservers
appservers

[all:vars]
ansible_ssh_private_key_file=~/.ssh/devops-p1-keypair.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Create group variables
echo "Creating group variables..."

cat > inventories/group_vars/webservers.yml << 'EOF'
---
nginx_user: nginx
nginx_group: nginx
nginx_port: 80
nginx_worker_processes: auto
nginx_worker_connections: 1024

upstream_servers:
  - { server: "10.0.2.29", port: "8080" }
  - { server: "10.0.5.17", port: "8080" }

ssl_enabled: false
ssl_cert_path: /etc/nginx/ssl/nginx.crt
ssl_key_path: /etc/nginx/ssl/nginx.key
EOF

cat > inventories/group_vars/appservers.yml << 'EOF'
---
java_home: /usr/lib/jvm/java-11-openjdk
tomcat_version: "9.0.95"
tomcat_user: tomcat
tomcat_group: tomcat
tomcat_port: 8080
tomcat_home: /opt/tomcat
tomcat_memory_min: 512m
tomcat_memory_max: 1024m

db_host: "YOUR_RDS_ENDPOINT"
db_port: 3306
db_name: loginapp
db_user: admin
db_password: "YOUR_DB_PASSWORD"

s3_bucket: "your-bucket-name"
app_version: "1.0.0"
EOF

cat > inventories/group_vars/all.yml << 'EOF'
---
timezone: "UTC"
aws_region: "us-east-1"

common_packages:
  - wget
  - curl
  - unzip
  - htop
  - tree
  - git

disable_root_login: true
allow_ssh_password_auth: false

cloudwatch_namespace: "DevOps-Project-Metrics"
log_retention_days: 7

dns_servers:
  - 8.8.8.8
  - 8.8.4.4
EOF

# Create test connectivity playbook
echo "Creating test connectivity playbook..."
cat > playbooks/test-connectivity.yml << 'EOF'
---
- name: Test connectivity to all servers
  hosts: all
  gather_facts: yes
  tasks:
    - name: Print server information
      debug:
        msg: "Connected to {{ inventory_hostname }} - OS: {{ ansible_distribution }}"
    
    - name: Check uptime
      command: uptime
      register: uptime_result
    
    - name: Display uptime
      debug:
        msg: "Uptime: {{ uptime_result.stdout }}"

    - name: Check free memory
      command: free -m
      register: memory_result
    
    - name: Display memory info
      debug:
        msg: "{{ memory_result.stdout_lines }}"

    - name: Test sudo access
      command: whoami
      become: yes
      register: sudo_test
    
    - name: Display sudo test
      debug:
        msg: "Sudo test: {{ sudo_test.stdout }}"
EOF

# Create Nginx installation playbook
echo "Creating Nginx installation playbook..."
cat > playbooks/install-nginx.yml << 'EOF'
---
- name: Install and configure Nginx
  hosts: webservers
  become: yes
  tasks:
    - name: Install Nginx
      yum:
        name: nginx
        state: present

    - name: Start and enable Nginx
      systemd:
        name: nginx
        state: started
        enabled: yes

    - name: Backup original nginx.conf
      copy:
        src: /etc/nginx/nginx.conf
        dest: /etc/nginx/nginx.conf.backup
        remote_src: yes
        backup: yes

    - name: Configure Nginx as reverse proxy
      copy:
        content: |
          upstream app_servers {
              server {{ hostvars[groups['appservers'][0]]['ansible_host'] }}:8080 max_fails=3 fail_timeout=30s;
              server {{ hostvars[groups['appservers'][1]]['ansible_host'] }}:8080 max_fails=3 fail_timeout=30s;
          }
          
          server {
              listen 80;
              server_name _;
              
              location /health {
                  access_log off;
                  return 200 "healthy\n";
                  add_header Content-Type text/plain;
              }
              
              location / {
                  proxy_pass http://app_servers;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_connect_timeout 30;
                  proxy_send_timeout 30;
                  proxy_read_timeout 30;
                  proxy_buffering off;
              }
          }
        dest: /etc/nginx/conf.d/app.conf

    - name: Test Nginx configuration
      command: nginx -t
      register: nginx_test

    - name: Restart Nginx
      systemd:
        name: nginx
        state: restarted
EOF

# Create Tomcat installation playbook
echo "Creating Tomcat installation playbook..."
cat > playbooks/install-tomcat.yml << 'EOF'
---
- name: Install and configure Tomcat
  hosts: appservers
  become: yes
  vars:
    tomcat_version: "{{ tomcat_version }}"
    java_home: "{{ java_home }}"
    tomcat_user: "{{ tomcat_user }}"
    tomcat_group: "{{ tomcat_group }}"
    tomcat_home: "{{ tomcat_home }}"
    
  tasks:
    - name: Install Java 11 and required packages
      yum:
        name:
          - java-11-openjdk-devel
          - wget
          - tar
        state: present

    - name: Create tomcat group
      group:
        name: "{{ tomcat_group }}"
        system: yes

    - name: Create tomcat user
      user:
        name: "{{ tomcat_user }}"
        group: "{{ tomcat_group }}"
        system: yes
        shell: /bin/false
        home: "{{ tomcat_home }}"
        createhome: no

    - name: Download Tomcat
      get_url:
        url: "https://dlcdn.apache.org/tomcat/tomcat-9/v{{ tomcat_version }}/bin/apache-tomcat-{{ tomcat_version }}.tar.gz"
        dest: "/tmp/apache-tomcat-{{ tomcat_version }}.tar.gz"
        mode: '0644'

    - name: Extract Tomcat
      unarchive:
        src: "/tmp/apache-tomcat-{{ tomcat_version }}.tar.gz"
        dest: /opt
        remote_src: yes
        owner: "{{ tomcat_user }}"
        group: "{{ tomcat_group }}"
        creates: "/opt/apache-tomcat-{{ tomcat_version }}"

    - name: Create symlink for Tomcat
      file:
        src: "/opt/apache-tomcat-{{ tomcat_version }}"
        dest: "{{ tomcat_home }}"
        state: link
        owner: "{{ tomcat_user }}"
        group: "{{ tomcat_group }}"
        force: yes

    - name: Set permissions on Tomcat directories
      file:
        path: "{{ item }}"
        owner: "{{ tomcat_user }}"
        group: "{{ tomcat_group }}"
        mode: '0755'
        recurse: yes
      loop:
        - "{{ tomcat_home }}/bin"
        - "{{ tomcat_home }}/conf"
        - "{{ tomcat_home }}/webapps"
        - "{{ tomcat_home }}/work"
        - "{{ tomcat_home }}/temp"
        - "{{ tomcat_home }}/logs"

    - name: Create Tomcat systemd service
      copy:
        content: |
          [Unit]
          Description=Apache Tomcat Web Application Container
          After=network.target

          [Service]
          Type=forking
          Environment=JAVA_HOME={{ java_home }}
          Environment=CATALINA_PID={{ tomcat_home }}/temp/tomcat.pid
          Environment=CATALINA_HOME={{ tomcat_home }}
          Environment=CATALINA_BASE={{ tomcat_home }}
          Environment='CATALINA_OPTS=-Xms{{ tomcat_memory_min }} -Xmx{{ tomcat_memory_max }} -server -XX:+UseParallelGC'
          ExecStart={{ tomcat_home }}/bin/startup.sh
          ExecStop={{ tomcat_home }}/bin/shutdown.sh
          User={{ tomcat_user }}
          Group={{ tomcat_group }}
          UMask=0007
          RestartSec=10
          Restart=always

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/tomcat.service

    - name: Start and enable Tomcat
      systemd:
        name: tomcat
        state: started
        enabled: yes
        daemon_reload: yes

    - name: Wait for Tomcat to start
      wait_for:
        port: "{{ tomcat_port }}"
        host: "{{ ansible_default_ipv4.address }}"
        delay: 10
        timeout: 60
EOF

# Create S3 setup playbook
echo "Creating S3 setup playbook..."
cat > playbooks/setup-s3-bucket.yml << 'EOF'
---
- name: Setup S3 bucket for application artifacts
  hosts: localhost
  connection: local
  gather_facts: no
  vars:
    bucket_name: "devops-project-artifacts-{{ ansible_date_time.epoch }}"
    aws_region: "{{ aws_region }}"
    
  tasks:
    - name: Create S3 bucket for artifacts
      amazon.aws.s3_bucket:
        name: "{{ bucket_name }}"
        region: "{{ aws_region }}"
        state: present
        public_access:
          block_public_acls: true
          block_public_policy: true
          ignore_public_acls: true
          restrict_public_buckets: true
      register: s3_bucket

    - name: Enable S3 bucket versioning
      amazon.aws.s3_bucket:
        name: "{{ bucket_name }}"
        versioning: yes
        region: "{{ aws_region }}"

    - name: Display bucket information
      debug:
        msg: |
          S3 Bucket Created: {{ bucket_name }}
          Region: {{ aws_region }}

    - name: Save bucket name to file
      copy:
        content: |
          S3_BUCKET_NAME={{ bucket_name }}
          S3_REGION={{ aws_region }}
        dest: s3-config.env
EOF

# Create deployment from S3 playbook
echo "Creating S3 deployment playbook..."
cat > playbooks/deploy-from-s3.yml << 'EOF'
---
- name: Deploy Java Application from S3
  hosts: appservers
  become: yes
  vars:
    s3_bucket: "{{ lookup('env', 'S3_BUCKET_NAME') | default(s3_bucket) }}"
    app_version: "{{ lookup('env', 'LATEST_VERSION') | default(app_version) }}"
    
  tasks:
    - name: Stop Tomcat service
      systemd:
        name: tomcat
        state: stopped

    - name: Remove old application
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /opt/tomcat/webapps/ROOT.war
        - /opt/tomcat/webapps/ROOT

    - name: Download application from S3
      amazon.aws.s3_object:
        bucket: "{{ s3_bucket }}"
        object: "artifacts/login-app-latest.war"
        dest: "/opt/tomcat/webapps/ROOT.war"
        mode: get

    - name: Set ownership of WAR file
      file:
        path: /opt/tomcat/webapps/ROOT.war
        owner: "{{ tomcat_user }}"
        group: "{{ tomcat_group }}"
        mode: '0644'

    - name: Start Tomcat service
      systemd:
        name: tomcat
        state: started

    - name: Wait for application to deploy
      wait_for:
        path: /opt/tomcat/webapps/ROOT
        timeout: 120

    - name: Check application status
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:8080"
        method: GET
        status_code: 200
      register: app_check
      retries: 5
      delay: 10

    - name: Display deployment status
      debug:
        msg: "Deployment {{ 'SUCCESS' if app_check.status == 200 else 'FAILED' }} on {{ inventory_hostname }}"
EOF

# Create master deployment playbook
echo "Creating master deployment playbook..."
cat > playbooks/deploy-complete-stack.yml << 'EOF'
---
- import_playbook: install-tomcat.yml
- import_playbook: install-nginx.yml

- name: Final verification
  hosts: all
  become: yes
  tasks:
    - name: Check Nginx status
      systemd:
        name: nginx
      register: nginx_status
      when: inventory_hostname in groups['webservers']

    - name: Check Tomcat status
      systemd:
        name: tomcat
      register: tomcat_status
      when: inventory_hostname in groups['appservers']

    - name: Display status
      debug:
        msg: |
          Server: {{ inventory_hostname }}
          {% if inventory_hostname in groups['webservers'] %}
          Nginx: {{ nginx_status.status.ActiveState }}
          {% endif %}
          {% if inventory_hostname in groups['appservers'] %}
          Tomcat: {{ tomcat_status.status.ActiveState }}
          {% endif %}
EOF

# Create Nginx role
echo "Creating Nginx role..."
cat > roles/nginx/tasks/main.yml << 'EOF'
---
- name: Install Nginx
  yum:
    name: nginx
    state: present

- name: Start and enable Nginx
  systemd:
    name: nginx
    state: started
    enabled: yes

- name: Configure firewall for HTTP
  firewalld:
    service: http
    permanent: yes
    state: enabled
    immediate: yes
  ignore_errors: yes
EOF

# Create Tomcat role
echo "Creating Tomcat role..."
cat > roles/tomcat/tasks/main.yml << 'EOF'
---
- name: Install Java
  yum:
    name: java-11-openjdk-devel
    state: present

- name: Create tomcat user
  user:
    name: "{{ tomcat_user }}"
    system: yes
    shell: /bin/false
    home: "{{ tomcat_home }}"
    createhome: no

- name: Download and extract Tomcat
  unarchive:
    src: "https://dlcdn.apache.org/tomcat/tomcat-9/v{{ tomcat_version }}/bin/apache-tomcat-{{ tomcat_version }}.tar.gz"
    dest: /opt
    remote_src: yes
    owner: "{{ tomcat_user }}"
    group: "{{ tomcat_group }}"
    creates: "/opt/apache-tomcat-{{ tomcat_version }}"

- name: Create symlink
  file:
    src: "/opt/apache-tomcat-{{ tomcat_version }}"
    dest: "{{ tomcat_home }}"
    state: link
EOF

# Create Common role
echo "Creating Common role..."
cat > roles/common/tasks/main.yml << 'EOF'
---
- name: Install common packages
  yum:
    name: "{{ common_packages }}"
    state: present

- name: Set timezone
  timezone:
    name: "{{ timezone }}"

- name: Update packages
  yum:
    name: "*"
    state: latest
    update_cache: yes
EOF

# Create helper scripts
echo "Creating helper scripts..."

cat > update-rds-endpoint.sh << 'EOF'
#!/bin/bash
read -p "Enter RDS endpoint: " rds_endpoint
read -p "Enter DB password: " -s db_password
echo ""
sed -i "s/YOUR_RDS_ENDPOINT/$rds_endpoint/g" inventories/group_vars/appservers.yml
sed -i "s/YOUR_DB_PASSWORD/$db_password/g" inventories/group_vars/appservers.yml
echo "RDS configuration updated!"
EOF

cat > deploy-with-s3.sh << 'EOF'
#!/bin/bash
echo "Setting up S3 bucket..."
ansible-playbook playbooks/setup-s3-bucket.yml
source s3-config.env
export S3_BUCKET_NAME S3_REGION
echo "Deploying complete stack..."
ansible-playbook playbooks/deploy-complete-stack.yml
echo "Deployment complete!"
EOF

chmod +x update-rds-endpoint.sh deploy-with-s3.sh

# Create README
echo "Creating README..."
cat > README.md << 'EOF'
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
EOF

echo "==================================="
echo "Complete Ansible Setup Finished!"
echo "==================================="
echo ""
echo "Directory structure created:"
echo "- ansible.cfg"
echo "- inventories/ (hosts, group_vars/)"
echo "- playbooks/ (5 playbooks created)"
echo "- roles/ (nginx, tomcat, common)"
echo "- Helper scripts (update-rds-endpoint.sh, deploy-with-s3.sh)"
echo "- README.md"
echo ""
echo "Next steps:"
echo "1. Test connectivity: ansible all -m ping"
echo "2. Update RDS: ./update-rds-endpoint.sh"
echo "3. Deploy: ansible-playbook playbooks/deploy-complete-stack.yml"
echo ""
echo "Project ready for use!"
echo "==================================="