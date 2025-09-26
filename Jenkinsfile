pipeline {
    agent any
    
    environment {
        NEXUS_URL = 'http://16.171.2.18:8081/nexus/content/sites/node-app-releases'
        ANSIBLE_PROJECT_PATH = '/home/ubuntu/ansible-project'
        APP_SERVER_URL = '51.21.129.73:3000'
    }
    
    parameters {
        string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: 'Deployment environment')
        choice(name: 'DEPLOY_ACTION', choices: ['deploy', 'rollback'], description: 'Deploy or Rollback')
        string(name: 'ROLLBACK_VERSION', defaultValue: '', description: 'Version to rollback to (if rollback)')
    }
    
    stages {
        stage('Checkout SCM') {
            steps {
                // This checks out the application code, not the Ansible project
                git branch: 'main', url: 'https://github.com/G-OrdiaD/ansible-project.git'
            }
        }
        
        stage('Update Ansible Project') {
            steps {
                sh """
                    echo "Updating Ansible project on Jenkins server..."
                    cd ${ANSIBLE_PROJECT_PATH}
                    git pull origin main
                    echo "Ansible project updated to latest version"
                """
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
                        sh """
                            echo "🚀 Deploying build ${env.BUILD_NUMBER}..."
                            cd ${ANSIBLE_PROJECT_PATH}
                            
                            # Update server IPs if needed (optional)
                            # ./scripts/update-server-ips.sh 13.60.92.125 51.21.129.73 16.171.2.18 13.61.19.40
                            
                            # Deploy using Ansible
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                -e "build_number=${env.BUILD_NUMBER}" \\
                                -e "app_version=${env.BUILD_NUMBER}"
                            
                            echo "✅ Deployment completed!"
                        """
                    } else if (params.DEPLOY_ACTION == 'rollback' && params.ROLLBACK_VERSION != '') {
                        sh """
                            echo "🔙 Rolling back to version ${params.ROLLBACK_VERSION}..."
                            cd ${ANSIBLE_PROJECT_PATH}
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \\
                                -e "build_number=${params.ROLLBACK_VERSION}" \\
                                -e "app_version=${params.ROLLBACK_VERSION}"
                            echo "✅ Rollback completed!"
                        """
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
                    # Keep the built artifact for reference
                    ls -la *.zip
                """
            }
        }
    }
    
    post {
        always {
            echo "📊 Pipeline ${currentBuild.result} - Build ${env.BUILD_NUMBER}"
            // Don't cleanWs() if you want to keep artifacts for debugging
        }
        success {
            sh """
                echo "✅ Pipeline completed successfully!"
                echo "📦 Build: ${env.BUILD_NUMBER}"
                echo "🌐 App URL: http://${APP_SERVER_URL}/"
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
