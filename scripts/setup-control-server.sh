#!/bin/bash
echo "Setting up Ansible control server..."

# Install Ansible
sudo yum update -y
sudo yum install -y python3-pip
sudo pip3 install ansible

# Clone project
cd ~
git clone https://github.com/G-OrdiaD/ansible-project.git
cd ansible-project

# Setup SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible-key -N ""
echo "SSH Public Key:"
cat ~/.ssh/ansible-key.pub
echo "Copy this key to other servers!"

echo "Control server setup complete!"