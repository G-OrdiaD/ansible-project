# Node.js App with Reverse Proxy, CI/CD, MongoDB, and SonarQube

This project demonstrates the deployment of a simple Node.js application using a modern DevOps toolchain. It features a Jenkins CI/CD pipeline with code quality analysis that automates the build, testing, and deployment process to an environment with an Nginx reverse proxy and MongoDB.

## 🏗️ Project Architecture

The infrastructure consists of the following components:

*   **Jenkins Master (Ubuntu):** Orchestrates the CI/CD pipeline and manages all Jenkins operations.
*   **Control Node / Manager (Amazon Linux):** Executes Ansible playbooks for infrastructure provisioning and application deployment.
*   **Application Server (CentOS 7):** Hosts the Node.js application, Nginx reverse proxy, and MongoDB database.
*   **Nexus Server (CentOS 7):** Hosts Sonatype Nexus artifact repository.

## 📋 Prerequisites

Ensure you have the following EC2 instances running:
- **1 x Jenkins Master** (Ubuntu)
- **1 x Control Node / Manager** (Amazon Linux) 
- **1 x Application Server** (CentOS 7)
- **1 x Nexus Server** (CentOS 7)

## ⚙️ Technologies Used

*   **Application Stack:** Node.js, Express.js, MongoDB
*   **Web Server & Reverse Proxy:** Nginx
*   **CI/CD Orchestration:** Jenkins
*   **Configuration Management:** Ansible
*   **Artifact Repository:** Sonatype Nexus
*   **Code Quality:** SonarQube
*   **Infrastructure:** AWS EC2
*   **Operating Systems:** Ubuntu, Amazon Linux, CentOS 7

## 🔧 Implementation Details

### Infrastructure Provisioning
All application stack components are installed and configured on the Application Server (CentOS 7) using Ansible playbooks executed from the Control Node:

- **Node.js Runtime** - Application execution environment
- **Nginx Reverse Proxy** - Serves the app on port 80
- **MongoDB Database** - Data persistence layer

### Jenkins Pipeline Stages
The Jenkinsfile defines a robust pipeline with the following stages:

1.  **Checkout:** Pulls the latest source code from the GitHub repository.
2.  **SonarQube Analysis:** Performs static code analysis and enforces quality gates.
3.  **Build & Package:** Installs Node.js dependencies and creates a production-ready artifact (ZIP file).
4.  **Upload to Nexus:** Publishes the versioned artifact to the Nexus repository.
5.  **Trigger Ansible Deployment:** Initiates Ansible playbooks on the Control Node to provision and deploy to the Application Server.

## 🎯 Expected Output

Upon successful deployment, navigating to your application server's public IP address in a web browser will display the message:

> **I am building pipelines like a pro!**

## 📁 Repository Structure

```
├── SRC/                    # Node.js Application Source Code
│   ├── package.json
│   ├── init.js
│   └── index.js
├── scripts/               # Server setup and configuration scripts
│   ├── setup-control-servers.sh
│   └── update-ips.sh
├── inventory/             # Ansible inventory configuration
│   ├── hosts.ini
│   └── group_vars/
│       └── all.yml
├── ansible/               # Ansible playbooks and roles
│   ├── playbook.yml
│   └── roles/
│       ├── nodejs-nginx/
│       ├── mongodb/
│       └── app-deploy/
├── Jenkinsfile           # Main CI/CD pipeline definition
├── ansible.cfg           # Ansible configuration
├── .gitignore
└── README.md
```

## 💡 Code Quality Integration

Despite the application's simplicity (only 3 basic JavaScript files), this project integrates SonarQube to demonstrate:
- Automated code quality checks in the CI/CD pipeline
- Quality gate enforcement before deployment
- Technical debt tracking
- Code smell detection
- Security vulnerability scanning

## 🚀 Getting Started

1. Clone this repository
2. Run setup scripts from `scripts/` directory to configure control servers
3. Update server IPs using `scripts/update-ips.sh`
4. Configure Jenkins master with required credentials and plugins
5. Set up Control Node with Ansible and necessary access
6. Configure SonarQube server and quality gates
7. Run the Jenkins pipeline

## 🤝 Contributing
Contributions, issues, and feature requests are welcome. Feel free to check the issues page.

## 📄 License
This project is licensed under the [MIT License](LICENSE).
