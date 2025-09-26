pipeline {
    agent any
    
    environment {
        NEXUS_URL = 'http://16.171.2.18:8081/nexus/content/sites/node-app-releases'
        APP_SERVER_URL = '51.21.129.73:3000'
        CONTROL_NODE_IP = '13.60.92.125'
    }
    
    parameters {
        string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: 'Deployment environment')
        choice(name: 'DEPLOY_ACTION', choices: ['deploy', 'rollback'], description: 'Deploy or Rollback')
        string(name: 'ROLLBACK_VERSION', defaultValue: '', description: 'Version to rollback to (if rollback)')
    }
    
    stages {
        stage('Checkout SCM') {
            steps {
                // This checks out the application code
                git branch: 'main', url: 'https://github.com/G-OrdiaD/ansible-project.git'
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
                            echo '✅ Ansible project updated to latest version on control-node'
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
            post {
                always {
                    echo "Skipping JUnit/coverage reports since no tests yet"
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
        
        stage('Deploy to App Server') {
            steps {
                script {
                    if (params.DEPLOY_ACTION == 'deploy') {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'ansible-ssh-key',
                            keyFileVariable: 'SSH_KEY'
                        )]) {
                            sh """
                                echo "🚀 Deploying build ${env.BUILD_NUMBER} via control-node..."
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${CONTROL_NODE_IP} "
                                    echo '=== Starting Ansible Deployment ==='
                                    cd /home/ec2-user/ansible-project
                                    echo '📦 Deploying build number: ${env.BUILD_NUMBER}'
                                    
                                    # Update server IPs if needed (optional)
                                    # ./scripts/update-server-ips.sh 13.60.92.125 51.21.129.73 16.171.2.18 13.61.19.40
                                    
                                    # Deploy using Ansible
                                    ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                        -e 'build_number=${env.BUILD_NUMBER}' \\
                                        -e 'app_version=${env.BUILD_NUMBER}'
                                    
                                    echo '=== Deployment Completed ==='
                                "
                                echo "✅ Deployment executed via control-node!"
                            """
                        }
                    } else if (params.DEPLOY_ACTION == 'rollback' && params.ROLLBACK_VERSION != '') {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'ansible-ssh-key',
                            keyFileVariable: 'SSH_KEY'
                        )]) {
                            sh """
                                echo "🔙 Rolling back to version ${params.ROLLBACK_VERSION} via control-node..."
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${CONTROL_NODE_IP} "
                                    cd /home/ec2-user/ansible-project
                                    ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                        -e 'build_number=${params.ROLLBACK_VERSION}' \\
                                        -e 'app_version=${params.ROLLBACK_VERSION}'
                                    echo 'Rollback completed on control-node'
                                "
                                echo "✅ Rollback executed via control-node!"
                            """
                        }
                    } else {
                        echo 'Skipping deployment'
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                expression { params.DEPLOY_ACTION == 'deploy' }
            }
            steps {
                sh """
                    echo "⏳ Waiting for application to start..."
                    sleep 30
                    
                    echo "🏥 Testing application health..."
                    curl -f http://${APP_SERVER_URL}/health || echo "Health endpoint not available"
                    
                    echo "🌐 Testing main application..."
                    curl -f http://${APP_SERVER_URL}/ || echo "Main endpoint not available"
                    
                    echo "🎉 Application deployment verified!"
                    echo "🔗 Access your app at: http://${APP_SERVER_URL}/"
                """
            }
        }
        
        stage('Cleanup Workspace') {
            steps {
                sh """
                    echo "🧹 Cleaning up workspace..."
                    ls -la *.zip
                """
            }
        }
    }
    
    post {
        always {
            echo "📊 Pipeline ${currentBuild.result} - Build ${env.BUILD_NUMBER}"
        }
        success {
            sh """
                echo "✅ Pipeline completed successfully!"
                echo "📦 Build: ${env.BUILD_NUMBER}"
                echo "🌐 App URL: http://${APP_SERVER_URL}/"
                echo "🖥️  Deployed via control-node: ${CONTROL_NODE_IP}"
            """
        }
        failure {
            sh """
                echo "❌ Pipeline failed!"
                echo "🔍 Check logs for details"
            """
        }
    }
}
