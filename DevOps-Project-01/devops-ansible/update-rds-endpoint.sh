#!/bin/bash
read -p "Enter RDS endpoint: " rds_endpoint
read -p "Enter DB password: " -s db_password
echo ""
sed -i "s/YOUR_RDS_ENDPOINT/$rds_endpoint/g" inventories/group_vars/appservers.yml
sed -i "s/YOUR_DB_PASSWORD/$db_password/g" inventories/group_vars/appservers.yml
echo "RDS configuration updated!"
