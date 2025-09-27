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
        CONTROL_NODE_PUBLIC_IP = "13.60.92.125"
        NEXUS_IP = "13.60.63.31"
        APP_SERVER_LOGICAL_NAME = "app"
        NEXUS_URL = "http://${NEXUS_IP}:8081/nexus/content/sites/node-app-releases/"
    }

    stages {
        stage('Checkout SCM') {
            steps {
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
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                cd /home/ec2-user/ansible-project
                                git reset --hard HEAD
                                git clean -fd
                                git pull origin main
                            "
                        """
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                echo '✅ SSH connection successful to Control Node!'
                                cd /home/ec2-user/ansible-project
                                ansible --version
                                ansible app,nexus,control-node -i inventory/hosts.ini -m ping
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
                    sh """
                        zip -r ../app-${env.BUILD_NUMBER}.zip . -x 'node_modules/*' '.git/*' '*.gitignore'
                    """
                    sh "ls -la ../app-${env.BUILD_NUMBER}.zip"
                }
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
                        curl -v --user "\$NEXUS_USER:\$NEXUS_PASS" --upload-file "app-${env.BUILD_NUMBER}.zip" "${env.NEXUS_URL}app-${env.BUILD_NUMBER}.zip"
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
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                            cd /home/ec2-user/ansible-project
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml -e 'build_number=${env.BUILD_NUMBER}' -e 'target_host=${env.APP_SERVER_LOGICAL_NAME}'
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
                    sh "sleep 10"
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                            ansible ${env.APP_SERVER_LOGICAL_NAME} -i inventory/hosts.ini -m uri -a 'url=http://${env.APP_SERVER_LOGICAL_NAME}:3000/ method=GET status_code=200'
                            ansible ${env.APP_SERVER_LOGICAL_NAME} -i inventory/hosts.ini -m uri -a 'url=http://${env.APP_SERVER_LOGICAL_NAME}/ method=GET status_code=200'
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
                    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        def appServerIP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ec2-user@${env.CONTROL_NODE_PUBLIC_IP} "
                                    cd /home/ec2-user/ansible-project
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        def summary = """
🎉 DEPLOYMENT SUCCESSFUL - BUILD #${env.BUILD_NUMBER}

📱 APPLICATION ACCESS URLs:

🔗 Direct API: http://${appServerIP}:3000
🌐 Production: http://${appServerIP}/

🔧 Server Details:
   App Server: ${appServerIP}
   Control Node: ${env.CONTROL_NODE_PUBLIC_IP}
   Build: #${env.BUILD_NUMBER}
   Time: ${new Date().format('yyyy-MM-dd HH:mm:ss')}

✅ All services running and accessible.
"""
                        echo summary
                        writeFile file: 'deployment-summary.txt', text: summary
                        archiveArtifacts artifacts: 'deployment-summary.txt', fingerprint: true
                    }
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
