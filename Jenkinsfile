pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['validate', 'deploy'],
            description: 'Choose deployment action (validate for test/build only, deploy for full rollout)'
        )
    }
    
    environment {
        CONTROL_NODE_PUBLIC_IP = "13.60.92.125" // The actual IP of your Control Node
        NEXUS_IP = "16.171.2.18"                 // The actual IP of your Nexus server
        
        // This is the name Ansible uses internally to target the host in its inventory file.
        APP_SERVER_LOGICAL_NAME = "app"
        
        // --- Derived URLs ---
        NEXUS_URL = "http://${NEXUS_IP}:8081/nexus/content/sites/node-app-releases/"
        APP_SERVER_URL = "${APP_SERVER_LOGICAL_NAME}:3000"
    }
    
    stages {
        
        stage('Checkout SCM') {
            steps {
                // Checkout the Ansible project repository
                git branch: 'main', url: 'https://github.com/G-OrdiaD/ansible-project.git'
            }
        }
        
        stage('Setup Control Node & Verify') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'ansible-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        // 1. Resolve Hostnames via Control Node's known IP
                        echo "Attempting initial SSH connection using fixed IP: ${CONTROL_NODE_PUBLIC_IP}"
                        
                        // Get the Control Node's resolved IP (from its own inventory)
                        env.CONTROL_NODE_IP_FROM_INVENTORY = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.control.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        // Get the App Server's resolved IP (from the Control Node's inventory)
                        env.APP_SERVER_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        echo "Control Node Inventory IP: ${env.CONTROL_NODE_IP_FROM_INVENTORY}"
                        echo "App Server Inventory IP: ${env.APP_SERVER_IP}"

                        // 2. Verify Control Node Access and Ansible Ping
                        echo "Verifying Control Node access and Ansible connectivity..."
                        sh """
                            # SSH connection is established using the fixed IP
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                                echo '✅ SSH connection successful to Control Node!'
                                cd /home/ec2-user/ansible-project
                                ansible --version
                                
                                # Use the logical name set in environment for Ansible commands
                                ansible all -i inventory/hosts.ini -m ping
                            "
                        """
                        
                        // 3. Update Control Node Project (Ansible playbooks)
                        echo "Updating Git repository on Control Node..."
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                                cd /home/ec2-user/ansible-project
                                git pull origin main
                            "
                        """
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                dir('src') {
                    // Assuming 'npm test' exists in the src directory
                    sh 'npm test' 
                }
            }
        }
        
        stage('Build Package') {
            steps {
                dir('src') {
                    sh """
                        zip -r ../app-\${env.BUILD_NUMBER}.zip . \\
                        -x 'node_modules/*' '.git/*' '*.gitignore'
                    """
                }
                archiveArtifacts artifacts: "app-${env.BUILD_NUMBER}.zip", onlyIfSuccessful: true
            }
        }
        
        stage('Publish to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-creds', 
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        ARTIFACT_NAME="app-${env.BUILD_NUMBER}.zip"
                        echo "Uploading \${ARTIFACT_NAME} to Nexus: ${env.NEXUS_URL}"
                        
                        # Use curl for authenticated upload 
                        curl -v --user \${NEXUS_USER}:\${NEXUS_PASS} \\
                             --upload-file \${ARTIFACT_NAME} \\
                             ${env.NEXUS_URL}/\${ARTIFACT_NAME}
                        
                        echo "Nexus upload successful."
                    """
                }
            }
        }
        
        stage('Deploy to App Server') {
            when {
                expression { params.DEPLOY_ACTION == 'deploy' }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    // Use the known public IP to SSH to the Control Node
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                            cd /home/ec2-user/ansible-project
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                -e 'build_number=\${env.BUILD_NUMBER}' \\
                                -e 'target_host=\${APP_SERVER_LOGICAL_NAME}'
                        "
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                expression { params.DEPLOY_ACTION == 'deploy' }
            }
            steps {
                sh 'sleep 10' 
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    // Use the known public IP to SSH to the Control Node
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_PUBLIC_IP} "
                            # Run verification commands on the Control Node using Ansible
                            # Check direct Node.js port (3000)
                            ansible \${APP_SERVER_LOGICAL_NAME} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_LOGICAL_NAME}:3000/ method=GET status_code=200'
                            
                            # Check Nginx reverse proxy (port 80)
                            ansible \${APP_SERVER_LOGICAL_NAME} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_LOGICAL_NAME}/ method=GET status_code=200'
                        "
                    """
                }
            }
        }
        
        stage('Deployment Summary') {
            when {
                expression { params.DEPLOY_ACTION == 'deploy' }
            }
            steps {
                script {
                    def summary = """
                    🎉 DEPLOYMENT SUCCESSFUL - BUILD #${env.BUILD_NUMBER}
                    
                    📱 APPLICATION ACCESS URLs:
                    
                    🔗 Direct Node.js API Access:
                        URL: http://${env.APP_SERVER_IP}:3000
                        Test: curl http://${env.APP_SERVER_IP}:3000
                    
                    🌐 Production Access (via Nginx Reverse Proxy):
                        URL: http://${env.APP_SERVER_IP}/
                        Test: curl http://${env.APP_SERVER_IP}/
                    
                    📊 Application Health:
                        Health Check: http://${env.APP_SERVER_IP}:3000/
                        Nginx Status: http://${env.APP_SERVER_IP}/nginx_status
                    
                    🔧 Server Details:
                        App Server IP: ${env.APP_SERVER_IP}
                        Control Node IP (Public): ${env.CONTROL_NODE_PUBLIC_IP}
                        Control Node IP (Inventory): ${env.CONTROL_NODE_IP_FROM_INVENTORY}
                        Nexus IP: ${env.NEXUS_IP}
                        Build Number: ${env.BUILD_NUMBER}
                        Deployment Time: ${new Date().format('yyyy-MM-dd HH:mm:ss')}
                    
                    ✅ All services are running and accessible.
                    """
                    
                    echo summary
                    writeFile file: 'deployment-summary.txt', text: summary
                    archiveArtifacts artifacts: 'deployment-summary.txt', fingerprint: true
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            script {
                if (params.DEPLOY_ACTION == 'deploy') {
                    echo "Deployment to ${APP_SERVER_LOGICAL_NAME} completed successfully!"
                }
            }
        }
        failure {
            echo "Pipeline failed! Check logs for errors."
        }
    }
}
