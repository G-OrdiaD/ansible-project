pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['validate', 'deploy'],
            description: 'Choose deployment action'
        )
        string(
            name: 'CONTROL_NODE_HOST',
            defaultValue: 'control-node',
            description: 'Control node hostname (from inventory)'
        )
        string(
            name: 'APP_SERVER_HOST', 
            defaultValue: 'app-server',
            description: 'App server hostname (from inventory)'
        )
        string(
            name: 'NEXUS_HOST',
            defaultValue: 'nexus',
            description: 'Nexus hostname (from inventory)'
        )
    }
    
    environment {
        NEXUS_URL = "http://${params.NEXUS_HOST}:8081/nexus/content/sites/node-app-releases/"
        APP_SERVER_URL = "${params.APP_SERVER_HOST}:3000"
    }
    
    stages {
        stage('Resolve Hostnames via Control Node') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'ansible-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        env.CONTROL_NODE_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${params.CONTROL_NODE_HOST} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.control.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                        
                        env.APP_SERVER_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${params.CONTROL_NODE_HOST} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                    }
                }
            }
        }
        
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
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                            echo '✅ SSH connection successful!'
                            cd /home/ec2-user/ansible-project
                            ansible --version
                            ansible all -i inventory/hosts.ini -m ping
                        "
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
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                            cd /home/ec2-user/ansible-project
                            git pull origin main
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
                        zip -r ../app-\${env.BUILD_NUMBER}.zip . \\
                        -x 'node_modules/*' '.git/*' '*.gitignore'
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
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
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
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ansible-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        sleep 10
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                            ansible \${APP_SERVER_HOST} -i inventory/hosts.ini -m uri \\
                            -a 'url=http://\${APP_SERVER_HOST}:3000/ method=GET status_code=200'
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
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'ansible-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        env.APP_SERVER_RESOLVED_IP = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@\${CONTROL_NODE_IP} "
                                    ansible-inventory -i inventory/hosts.ini --list | jq -r '.app_servers.hosts[0]'
                                "
                            """,
                            returnStdout: true
                        ).trim()
                    }
                    
                    def summary = """
                    🎉 DEPLOYMENT SUCCESSFUL - BUILD #${env.BUILD_NUMBER}
                    
                    📱 APPLICATION ACCESS URLs:
                    
                    🔗 Direct Node.js API Access:
                       URL: http://${env.APP_SERVER_RESOLVED_IP}:3000
                       Test: curl http://${env.APP_SERVER_RESOLVED_IP}:3000
                    
                    🌐 Production Access (via Nginx Reverse Proxy):
                       URL: http://${env.APP_SERVER_RESOLVED_IP}/
                       Test: curl http://${env.APP_SERVER_RESOLVED_IP}/
                    
                    📊 Application Health:
                       Health Check: http://${env.APP_SERVER_RESOLVED_IP}:3000/
                       Nginx Status: http://${env.APP_SERVER_RESOLVED_IP}/nginx_status
                    
                    🔧 Server Details:
                       App Server: ${env.APP_SERVER_RESOLVED_IP}
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
                }
            }
        }
    }
}
