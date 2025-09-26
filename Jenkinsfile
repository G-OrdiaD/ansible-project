pipeline {
    agent any
    
    environment {
        NEXUS_URL = 'http://16.171.2.18:8081/nexus/content/sites/node-app-releases'
        APP_SERVER_URL = '51.21.129.73:3000'
        CONTROL_NODE_IP = '13.60.92.125'
    }
    
    stages {
        stage('Checkout SCM') {
            steps {
                git branch: 'main', url: 'https://github.com/G-OrdiaD/ansible-project.git'
            }
        }
        
        stage('Verify Control-Node Access') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        echo "🔧 Verifying control-node access..."
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${CONTROL_NODE_IP} "
                            echo '✅ SSH connection successful!'
                            cd /home/ec2-user/ansible-project
                            echo '📁 Ansible project verified'
                            ansible --version
                            echo '🌐 Testing server connectivity...'
                            ansible all -i inventory/hosts.ini -m ping
                        " || {
                            echo "❌ Control-node verification failed!"
                            exit 1
                        }
                    """
                }
            }
        }
        
        stage('Update Control-Node Project') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        echo "🔄 Updating Ansible project on control-node..."
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${CONTROL_NODE_IP} "
                            cd /home/ec2-user/ansible-project
                            git pull origin main
                            echo '✅ Ansible project updated'
                        "
                    """
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
                    sh """
                        zip -r ../app-${env.BUILD_NUMBER}.zip . \\
                        -x 'node_modules/*' '.git/*' '*.gitignore'
                    """
                    sh "ls -la ../app-${env.BUILD_NUMBER}.zip"
                }
            }
        }
        
        stage('Verify Nexus Access') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        echo "📦 Verifying Nexus access..."
                        curl -f -u $NEXUS_USER:$NEXUS_PASS ${NEXUS_URL}/ || {
                            echo "❌ Nexus access verification failed!"
                            exit 1
                        }
                        echo "✅ Nexus access verified"
                    """
                }
            }
        }
        
        stage('Upload to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \\
                        --upload-file app-${env.BUILD_NUMBER}.zip \\
                        ${NEXUS_URL}/app-${env.BUILD_NUMBER}.zip
                    """
                }
            }
        }
        
        stage('Verify Artifact in Nexus') {
            steps {
                sh """
                    echo "🔍 Verifying artifact uploaded to Nexus..."
                    curl -f ${NEXUS_URL}/app-${env.BUILD_NUMBER}.zip || {
                        echo "❌ Artifact verification failed!"
                        exit 1
                    }
                    echo "✅ Artifact verified in Nexus"
                """
            }
        }
        
        stage('Deploy to App Server') {
            steps {
                script {
                    if (params.DEPLOY_ACTION == 'deploy') {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'ansible-ssh-key',
                            keyFileVariable: 'SSH_KEY'
                        )]) {
                            sh """
                                echo "🚀 Deploying build ${env.BUILD_NUMBER}..."
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${CONTROL_NODE_IP} "
                                    cd /home/ec2-user/ansible-project
                                    ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                        -e 'build_number=${env.BUILD_NUMBER}'
                                "
                            """
                        }
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh """
                    echo "⏳ Waiting for application to start..."
                    sleep 30
                    
                    echo "🏥 Verifying application health..."
                    curl -f http://${APP_SERVER_URL}/health || echo "⚠️ Health endpoint not available"
                    
                    echo "🌐 Verifying main application..."
                    curl -f http://${APP_SERVER_URL}/ || {
                        echo "❌ Application verification failed!"
                        exit 1
                    }
                    
                    echo "✅ Application verification successful!"
                """
            }
        }
    }
}
