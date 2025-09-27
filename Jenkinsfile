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
            description: 'Control node hostname'
        )
        string(
            name: 'APP_HOST', 
            defaultValue: 'app',
            description: 'App server hostname'
        )
        string(
            name: 'NEXUS_HOST',
            defaultValue: 'nexus',
            description: 'Nexus hostname'
        )
    }
    
    environment {
        NEXUS_REPO_URL = "http://${params.NEXUS_HOST}:8081/repository/node-app-releases/"
    }
    
    stages {
        stage('Resolve Hostnames') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        env.CONTROL_NODE_IP = resolveHost(params.CONTROL_NODE_HOST, 'control')
                        env.APP_SERVER_IP = resolveHost(params.APP_SERVER_HOST, 'app_servers')
                    }
                }
            }
        }
        
        stage('Checkout & Update Control Node') {
            steps {
                checkout scm
                updateControlNode()
            }
        }
        
        stage('Build & Test') {
            steps {
                dir('src') {
                    sh 'npm install && npm test'
                    sh "zip -r ../app-${env.BUILD_NUMBER}.zip . -x 'node_modules/*' '.git/*'"
                }
            }
        }
        
        stage('Nexus Upload') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                        curl -f -u $NEXUS_USER:$NEXUS_PASS ${NEXUS_REPO_URL} || exit 1
                        curl -u $NEXUS_USER:$NEXUS_PASS --upload-file app-${env.BUILD_NUMBER}.zip ${NEXUS_REPO_URL}app-${env.BUILD_NUMBER}.zip
                    """
                }
            }
        }
        
        stage('Deploy') {
            when { expression { params.DEPLOY_ACTION == 'deploy' } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    sh """
                        ssh -i $SSH_KEY ec2-user@${env.CONTROL_NODE_IP} "
                            cd /home/ec2-user/ansible-project
                            ansible-playbook -i inventory/hosts.ini ansible/playbooks/deploy-app.yml \
                                -e 'build_number=${env.BUILD_NUMBER}' \
                                -e 'nexus_url=${NEXUS_REPO_URL}'
                        "
                    """
                }
            }
        }
        
        stage('Verify & Summary') {
            when { expression { params.DEPLOY_ACTION == 'deploy' } }
            steps {
                verifyDeployment()
                deploymentSummary()
            }
        }
    }
    
    post {
        always {
            cleanWs()
            script {
                notifySlack(currentBuild.result)
            }
        }
    }
}

// Shared functions
def resolveHost(hostname, group) {
    return sh(
        script: """
            ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${hostname} "
                ansible-inventory -i inventory/hosts.ini --list | jq -r '.${group}.hosts[0]'
            "
        """,
        returnStdout: true
    ).trim()
}

def updateControlNode() {
    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'SSH_KEY')]) {
        sh """
            ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${env.CONTROL_NODE_IP} "
                cd /home/ec2-user/ansible-project
                git pull origin main
                ansible all -i inventory/hosts.ini -m ping
            "
        """
    }
}

def verifyDeployment() {
    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'SSH_KEY')]) {
        sh """
            ssh -i $SSH_KEY ec2-user@${env.CONTROL_NODE_IP} "
                ansible ${params.APP_SERVER_HOST} -i inventory/hosts.ini -m uri \
                    -a 'url=http://${params.APP_SERVER_HOST}:3000/ method=GET status_code=200'
                ansible ${params.APP_SERVER_HOST} -i inventory/hosts.ini -m uri \
                    -a 'url=http://${params.APP_SERVER_HOST}/ method=GET status_code=200'
            "
        """
    }
}

def deploymentSummary() {
    def summary = """
🎉 DEPLOYMENT SUCCESSFUL - BUILD #${env.BUILD_NUMBER}

📱 APPLICATION ACCESS URLs:

🔗 Direct API: http://${env.APP_SERVER_IP}:3000
🌐 Production: http://${env.APP_SERVER_IP}/

🔧 Server Details:
   App Server: ${env.APP_SERVER_IP}
   Build: #${env.BUILD_NUMBER}
   Time: ${new Date().format('yyyy-MM-dd HH:mm:ss')}
"""
    echo summary
    writeFile file: 'deployment-summary.txt', text: summary
    archiveArtifacts artifacts: 'deployment-summary.txt'
}

def notifySlack(buildResult) {
    def color = 'good'
    def status = 'SUCCESS'
    
    if (buildResult == 'FAILURE') {
        color = 'danger'
        status = 'FAILED'
    } else if (buildResult == 'UNSTABLE') {
        color = 'warning'
        status = 'UNSTABLE'
    }
    
    def message = """
${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}
Action: ${params.DEPLOY_ACTION}
Result: ${currentBuild.currentResult}
URL: ${env.BUILD_URL}
"""
    
    slackSend (
        channel: '#deployments',
        color: color,
        message: message
    )
}
