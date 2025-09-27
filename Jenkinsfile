pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['validate', 'deploy'],
            description: 'Choose deployment action (validate for test/build only, deploy for full rollout)'
        )
        string(
            name: 'CONTROL_NODE_HOST',
            defaultValue: 'control-node',
            description: 'Control node hostname (from inventory)'
        )
        string(
            name: 'APP_HOST', 
            defaultValue: 'app',
            description: 'App server hostname (from inventory)'
        )
        string(
            name: 'NEXUS_HOST',
            defaultValue: 'nexus',
            description: 'Nexus hostname (from inventory)'
        )
    }
    
    environment {
        // Base URL for Nexus repository to upload artifacts
        NEXUS_URL = "http://${params.NEXUS_HOST}:8081/nexus/content/sites/node-app-releases/"
    
        APP_SERVER_URL = "${params.APP_HOST}:3000"
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
                        // 1. Resolve Hostnames and store IPs in environment variables
                        echo "Resolving hostnames via Ansible inventory on Control Node..."
                        
                        env.CONTROL_NODE_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${params.CONTROL_NODE_HOST} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.control.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        env.APP_SERVER_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${params.CONTROL_NODE_HOST} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        echo "Control Node IP: ${env.CONTROL_NODE_IP}"
                        echo "App Server IP: ${env.APP_SERVER_IP}"

                        // 2. Verify Control Node Access and Ansible Ping
                        echo "Verifying Control Node access and Ansible connectivity..."
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                                echo '✅ SSH connection successful to Control Node!'
                                cd /home/ec2-user/ansible-project
                                ansible --version
                                ansible all -i inventory/hosts.ini -m ping
                            "
                        """
                        
                        // 3. Update Control Node Project (Ansible playbooks)
                        echo "Updating Git repository on Control Node..."
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
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
                    // Assuming node.js environment is available on the agent
                    sh 'npm test' 
                }
            }
        }
        
        stage('Build Package') {
            steps {
                dir('src') {
                    // Create application deployment zip package in the workspace root
                    sh """
                        zip -r ../app-\${env.BUILD_NUMBER}.zip . \\
                        -x 'node_modules/*' '.git/*' '*.gitignore'
                    """
                }
                archiveArtifacts artifacts: "app-${env.BUILD_NUMBER}.zip", onlyIfSuccessful: true
            }
        }
        
        // NEW STAGE: Publish the built artifact to Nexus
        stage('Publish to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-creds', // <-- UPDATED TO USE 'nexus-creds'
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
                    // Execute Ansible deployment playbook on the Control Node
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                            cd /home/ec2-user/ansible-project
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                -e 'build_number=\${env.BUILD_NUMBER}' \\
                                -e 'target_host=\${APP_SERVER_HOST}'
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
                // Wait for services to start and then run health checks via Ansible uri module
                sh 'sleep 10' 
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                            # Check direct Node.js port (3000)
                            ansible \${APP_SERVER_HOST} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_HOST}:3000/ method=GET status_code=200'
                            
                            # Check Nginx reverse proxy (port 80)
                            ansible \${APP_SERVER_HOST} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_HOST}/ method=GET status_code=200'
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
                    // Use previously resolved IPs (env.APP_SERVER_IP and env.CONTROL_NODE_IP)
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
                        App Server: ${env.APP_SERVER_IP}
                        Control Node: ${env.CONTROL_NODE_IP}
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
                    echo "Deployment to ${params.APP_SERVER_HOST} completed successfully!"
                }
            }
        }
        failure {
            echo "Pipeline failed! Check logs for errors."
        }
    }
}
