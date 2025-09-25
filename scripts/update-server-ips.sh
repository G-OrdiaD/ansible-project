#!/bin/bash
# Usage: ./update-server-ips.sh <control_ip> <app_ip> <nexus_ip> <jenkins_ip>

if [ $# -ne 4 ]; then
    echo "Usage: $0 <control_ip> <app_ip> <nexus_ip> <jenkins_ip>"
    exit 1
fi

CONTROL_IP="$1"
APP_IP="$2"
NEXUS_IP="$3"
JENKINS_IP="$4"

echo "Updating IP addresses:"
echo "Control: $CONTROL_IP"
echo "App: $APP_IP"
echo "Nexus: $NEXUS_IP"
echo "Jenkins: $JENKINS_IP"

# Check if we're in the right directory
if [ ! -d "ansible" ]; then
    echo "Error: ansible directory not found. Run this script from the project root."
    exit 1
fi

cd ansible

# Update group_vars/all.yml
cat > group_vars/all.yml << EOF
---
# Server IPs - Updated automatically
server_ips:
  ansible-control: "$CONTROL_IP"
  app-server: "$APP_IP"
  nexus-server: "$NEXUS_IP"
  jenkins-master: "$JENKINS_IP"

# This variable is crucial for updating the /etc/hosts file on each server
hosts_entries:
  - hostname: ansible-control
    ip: "$CONTROL_IP"
  - hostname: app-server
    ip: "$APP_IP"
  - hostname: nexus-server
    ip: "$NEXUS_IP"
  - hostname: jenkins-master
    ip: "$JENKINS_IP"

# Application settings
app_name: "nodejs-app"
app_port: 3000
app_user: "ec2-user"
app_group: "ec2-user"

# Nexus settings
nexus_port: 8081
nexus_repo: "node-app-releases"

# Jenkins settings
jenkins_port: 8080
EOF

echo "Updated group_vars/all.yml"

# Update /etc/hosts on the control node first
echo "Updating /etc/hosts on control node..."
sudo bash -c "cat > /tmp/new_hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# Ansible hosts - Updated by update-server-ips.sh
$CONTROL_IP control-node
$APP_IP app
$NEXUS_IP nexus
$JENKINS_IP jenkins-master
EOF"

sudo cp /etc/hosts /etc/hosts.backup
sudo cp /tmp/new_hosts /etc/hosts
sudo rm -f /tmp/new_hosts
echo "Updated /etc/hosts (backup created at /etc/hosts.backup)"

# Update hosts on all servers via Ansible
if [ -f "playbooks/update-all-host.yml" ]; then
    echo "Running ansible-playbook to update all servers..."
    ansible-playbook playbooks/update-all-host.yml
    if [ $? -eq 0 ]; then
        echo "Playbook executed successfully"
    else
        echo "Warning: Playbook execution failed, but IPs were updated locally"
    fi
else
    echo "Error: playbooks/update-all-host.yml not found"
    echo "IPs were updated in group_vars/all.yml and local /etc/hosts, but playbook was not run"
    exit 1
fi

echo "IPs updated successfully!"
echo "Control: $CONTROL_IP, App: $APP_IP, Nexus: $NEXUS_IP, Jenkins: $JENKINS_IP"