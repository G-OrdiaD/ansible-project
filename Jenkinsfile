pipeline {
    agent any
    
    environment {
        NEXUS_URL = 'http://nexus:8081/repository/node-app-releases'
        ANSIBLE_PROJECT_PATH = '/home/ec2-user/ansible-project/ansible'
    }
    
    parameters {
        string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: 'Deployment environment')
        choice(name: 'DEPLOY_ACTION', choices: ['deploy', 'rollback'], description: 'Deploy or Rollback')
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/G-OrdiaD/ansible-project.git'
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
                    junit '**/junit.xml'
                    publishHTML([target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'src/coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ]])
                }
            }
        }
        
        stage('Build Package') {
            steps {
                dir('src') {
                    sh """
                        zip -r ../app-${env.BUILD_NUMBER}.zip . \
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
                        curl -f -u $NEXUS_USER:$NEXUS_PASS \
                        -X PUT \
                        "${NEXUS_URL}/app-${env.BUILD_NUMBER}.zip" \
                        -T "app-${env.BUILD_NUMBER}.zip"
                    """
                }
            }
        }
        
        stage('Deploy to App Server') {
            steps {
                script {
                    if (params.DEPLOY_ACTION == 'deploy') {
                        sshagent(['ansible-control-key']) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ec2-user@ansible-control '
                                    cd ${ANSIBLE_PROJECT_PATH} &&
                                    git pull origin main &&
                                    ansible-playbook playbooks/deploy-app.yml \
                                        -e "build_number=${env.BUILD_NUMBER}" \
                                        -e "app_version=${env.BUILD_NUMBER}"
                                '
                            """
                        }
                    } else {
                        echo 'Rollback selected - skipping deployment'
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh """
                    curl -f http://app-server/health
                    curl -f http://app-server/ | grep "building pipelines like a pro"
                """
            }
        }
    }
    
    post {
        always {
            echo "Pipeline ${currentBuild.result} - Build ${env.BUILD_NUMBER}"
            cleanWs()
        }
        success {
            slackSend channel: '#deployments',
                     message: "✅ SUCCESS: ${env.JOB_NAME} - ${env.BUILD_NUMBER} deployed to ${params.DEPLOY_ENV}"
            emailext (
                subject: "SUCCESS: Job ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}",
                body: "Deployment completed successfully.\nCheck: http://app-server",
                to: "team@yourcompany.com"
            )
        }
        failure {
            slackSend channel: '#deployments',
                     message: "❌ FAILED: ${env.JOB_NAME} - ${env.BUILD_NUMBER} failed in ${currentBuild.result}"
            emailext (
                subject: "FAILED: Job ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: "team@yourcompany.com"
            )
        }
    }
}