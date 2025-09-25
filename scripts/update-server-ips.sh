#!/bin/bash
# Usage: ./update-ips.sh <control_ip> <app_ip> <nexus_ip> <jenkins_ip>

if [ $# -ne 4 ]; then
    echo "Usage: $0 <control_ip> <app_ip> <nexus_ip> <jenkins_ip>"
    exit 1
fi

cd infrastructure/ansible

# Update group_vars
cat > group_vars/all.yml << EOF
---
server_ips:
  ansible-control: "$1"
  app-server: "$2"
  nexus-server: "$3"
  jenkins-master: "$4"

app_name: "nodejs-app"
app_port: 3000
app_user: "ec2-user"
app_group: "ec2-user"
nexus_port: 8081
nexus_repo: "node-app-releases"
jenkins_port: 8080
EOF

# Update hosts on all servers
ansible-playbook playbooks/update-all-host.yml

echo "IPs updated successfully!"
echo "Control: $1, App: $2, Nexus: $3, Jenkins: $4"