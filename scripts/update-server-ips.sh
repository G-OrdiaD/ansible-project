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

# Update group_vars/all.yml
mkdir -p inventory/group_vars
cat > inventory/group_vars/all.yml << EOF
---
# Server IPs - Updated automatically
server_ips:
  control-node: "$CONTROL_IP"
  app: "$APP_IP"
  nexus: "$NEXUS_IP"
  jenkins-master: "$JENKINS_IP"

# This variable is crucial for updating the /etc/hosts file on each server
hosts_entries:
  - hostname: control-node
    ip: "$CONTROL_IP"
  - hostname: app
    ip: "$APP_IP"
  - hostname: nexus
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

echo "Updated inventory/group_vars/all.yml"

# Update /etc/hosts on the control node first
echo "Updating /etc/hosts on control node..."
# WARNING: This complex sudo bash -c block is highly prone to shell parsing errors (EOF error).
# It is kept as per user request to maintain structure, but the error may persist.
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
PLAYBOOK_PATH="ansible/playbooks/update-all-host.yml" 

echo "Debug: Checking if playbook exists at: ${PLAYBOOK_PATH}"
if [ -f "${PLAYBOOK_PATH}" ]; then
    echo "Debug: Playbook found! Running ansible-playbook..."

    echo "Debug: Using inventory file: ../inventory/hosts.ini"
    cd ansible
    
    # Run the playbook. Note: The playbook path must be relative to the current directory ('ansible').
    ansible-playbook -i ../inventory/hosts.ini playbooks/update-all-host.yml
    if [ $? -eq 0 ]; then
        echo "Playbook executed successfully"
    else
        echo "Warning: Playbook execution failed, but IPs were updated locally"
    fi
else
    echo "Error: ${PLAYBOOK_PATH} not found"
    echo "IPs were updated in inventory/group_vars/all.yml and local /etc/hosts, but playbook was not run"
    exit 1
fi

echo "IPs updated successfully!"
echo "Control: $CONTROL_IP, App: $APP_IP, Nexus: $NEXUS_IP, Jenkins: $JENKINS_IP"
