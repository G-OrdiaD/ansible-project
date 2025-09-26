pipeline {
    agent any
    
    environment {
        NEXUS_URL = 'http://16.171.2.18:8081/nexus/content/sites/node-app-releases'
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
                    echo "Skipping JUnit/coverage reports since no tests yet"
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
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \
                        --upload-file app-${env.BUILD_NUMBER}.zip \
                        ${NEXUS_URL}/app-${env.BUILD_NUMBER}.zip
                    """
                }
            }
        }
        
        stage('Deploy to App Server') {
            steps {
                script {
                    if (params.DEPLOY_ACTION == 'deploy') {
                        sshagent(['ec2-user']) {
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
    }
}
