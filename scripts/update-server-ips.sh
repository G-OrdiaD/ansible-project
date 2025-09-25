!/bin/bash
# Sync this script to control server when IPs change

echo "Updating /etc/hosts on control server..."

sudo bash -c 'cat > /etc/hosts << EOF
127.0.0.1 localhost

# DevOps Project Servers - Update these IPs when they change
'"$1"' app-server
'"$2"' nexus-server
'"$3"' jenkins-master
'"$4"' ansible-control
EOF'

echo "Updated /etc/hosts with:"
echo "app-server: $1"
echo "nexus-server: $2" 
echo "jenkins-master: $3"
echo "ansible-control: $4"