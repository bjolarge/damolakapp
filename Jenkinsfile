pipeline {
    agent any

    environment {
        APP_NAME       = 'damolakapp'
        AWS_REGION     = 'eu-north-1'
        ECR_REPO_URL   = credentials('ECR_REPO_URL')   // e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/damolakapp
        EC2_HOST       = credentials('EC2_HOST')        // your EC2 public IP
        EC2_USER       = 'ec2-user'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Building branch: ${env.BRANCH_NAME} | Build #${env.BUILD_NUMBER}"
            }
        }

        stage('Build') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Test') {
            steps {
                sh 'npm test -- --passWithNoTests'
            }
            post {
                always {
                    // Publish test results if junit reporter is configured
                    // junit 'test-results/**/*.xml'
                    echo 'Tests completed'
                }
            }
        }

        stage('Docker Build & Push to ECR') {
            steps {
                withAWS(credentials: 'AWS_CREDENTIALS', region: "${AWS_REGION}") {
                    sh '''
                        # Authenticate Docker to ECR
                        aws ecr get-login-password --region $AWS_REGION | \
                          docker login --username AWS --password-stdin $ECR_REPO_URL

                        # Build image with both a build number tag and latest
                        docker build -t $ECR_REPO_URL:$IMAGE_TAG -t $ECR_REPO_URL:latest .

                        # Push both tags
                        docker push $ECR_REPO_URL:$IMAGE_TAG
                        docker push $ECR_REPO_URL:latest
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ['EC2_SSH_KEY']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST << EOF
                            # Re-authenticate to ECR from EC2
                            aws ecr get-login-password --region $AWS_REGION | \
                              docker login --username AWS --password-stdin $ECR_REPO_URL

                            # Pull the latest image
                            docker pull $ECR_REPO_URL:latest

                            # Stop and remove old container if running
                            docker stop $APP_NAME || true
                            docker rm $APP_NAME || true

                            # Run new container using env file populated by Terraform user_data
                            docker run -d \
                              --name $APP_NAME \
                              --env-file /etc/app.env \
                              --restart unless-stopped \
                              -p 3000:3000 \
                              $ECR_REPO_URL:latest

                            # Clean up old images to save disk space
                            docker image prune -f
EOF
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful! App running at http://$EC2_HOST"
        }
        failure {
            echo "Pipeline failed at stage. Check logs above."
        }
        always {
            // Clean up local Docker images on Jenkins agent
            sh 'docker image prune -f || true'
        }
    }
}