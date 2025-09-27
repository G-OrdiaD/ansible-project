pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['validate', 'deploy'],
            description: 'Choose deployment action'
        )
    }

    environment {
        // Hardcoded IPs for Jenkins agent connectivity (Nexus and Control Node)
        CONTROL_NODE_PUBLIC_IP = "13.60.92.125"
        NEXUS_IP = "13.60.63.31" // Verified public IP for Nexus
        APP_SERVER_LOGICAL_NAME = "app" // Logical name used in Ansible inventory
        
        NEXUS_URL = "http://${NEXUS_IP}:8081/nexus/content/sites/node-app-releases/"
        // Note: APP_SERVER_URL is informational only; deployment uses Ansible.
    }

    stages {
        stage('Checkout SCM') {
            steps {
                // Checkout the repository for the Jenkins agent to build the package
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
                        // 1. Update the Control Node's local Ansible project repository
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                cd /home/ec2-user/ansible-project
                                git pull origin main
                            "
                        """

                        // 2. Verify connection and Ansible's ability to reach all hosts
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                echo '✅ SSH connection successful to Control Node!'
                                cd /home/ec2-user/ansible-project
                                ansible --version
                                ansible all -i inventory/hosts.ini -m ping
                            "
                        """
                    }
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('src') {
                    sh 'npm test'
                }
            }
        }

        stage('Build Package') {
            steps {
                dir('src') {
                    // Create the application package (ZIP file)
                    sh """
                        zip -r ../app-\${env.BUILD_NUMBER}.zip . \\
                        -x 'node_modules/*' '.git/*' '*.gitignore'
                    """
                }
            }
        }

        stage('Publish to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-creds', // This must match your Jenkins Credential ID
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        # Publish the application package to Nexus repository
                        curl -v --user "\$NEXUS_USER:\$NEXUS_PASS" --upload-file "app-\${env.BUILD_NUMBER}.zip" \
                        "${env.NEXUS_URL}app-\${env.BUILD_NUMBER}.zip"
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
                    // Execute Ansible playbook on the Control Node to deploy the app
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
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
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    // Give the application a few seconds to start
                    sh "sleep 10" 
                    
                    // Use Ansible URI module to hit the app endpoint via the Control Node
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                            # Check Node.js application direct port
                            ansible \${APP_SERVER_LOGICAL_NAME} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_LOGICAL_NAME}:3000/ method=GET status_code=200'
                            
                            # Check application via Nginx reverse proxy (standard web port)
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
                    // We can reuse the known IPs from the environment block
                    def appServerIP = sh(
                        script: """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                cd /home/ec2-user/ansible-project && \
                                ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                            "
                        """,
                        returnStdout: true
                    ).trim()
                    
                    def summary = """
                    🎉 DEPLOYMENT SUCCESSFUL - BUILD #${env.BUILD_NUMBER}

                    📱 APPLICATION ACCESS URLs:
                    
                    🔗 Direct Node.js API Access:
                        URL: http://${appServerIP}:3000
                        Test: curl http://${appServerIP}:3000
                    
                    🌐 Production Access (via Nginx Reverse Proxy):
                        URL: http://${appServerIP}/
                        Test: curl http://${appServerIP}/
                    
                    🔧 Server Details:
                        App Server Hostname: ${env.APP_SERVER_LOGICAL_NAME}
                        App Server Public IP: ${appServerIP}
                        Control Node IP: ${env.CONTROL_NODE_PUBLIC_IP}
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
    }
}
