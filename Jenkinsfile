pipeline {
  agent any

  tools {
    maven 'Maven3'
  }

  environment {
    IMAGE_NAME = 'omari87/mini-devsecops-app'
    IMAGE_TAG  = "${BUILD_NUMBER}"
    SCANNER_HOME = tool('SonarScanner')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Check Environment') {
      steps {
        sh '''
          set -e
          echo "=== Versions ==="
          java -version
          mvn -version
          git --version
          docker --version
          trivy --version
        '''
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -e
          mvn clean package -DskipTests
          ls -lah target/
        '''
      }
    }

    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh '''
            set -e
            mvn sonar:sonar \
              -Dsonar.projectKey=mini-devsecops-app \
              -Dsonar.projectName=mini-devsecops-app
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('OWASP Dependency-Check') {
      steps {
        withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
          dependencyCheck(
            odcInstallation: 'DependencyCheck',
            additionalArguments: "--scan . --format XML --format HTML --nvdApiKey ${NVD_API_KEY}",
            stopBuild: false
          )
        }
      }
    }

    stage('Publish Dependency-Check Report') {
      steps {
        dependencyCheckPublisher(
          pattern: '**/dependency-check-report.xml',
          stopBuild: false,
          failedTotalCritical: 9999,
          failedTotalHigh: 9999,
          unstableTotalHigh: 1,
          unstableTotalMedium: 1
        )
      }
    }

    stage('Trivy FS Scan') {
      steps {
        sh '''
          set -e
          trivy fs --no-progress --exit-code 0 --severity HIGH,CRITICAL .
        '''
      }
    }

    stage('Docker Build') {
      steps {
        sh '''
          set -e
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        '''
      }
    }

    stage('Trivy Image Scan') {
      steps {
        sh '''
          set -e
          trivy image --no-progress --exit-code 0 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
        '''
      }
    }

    stage('Docker Hub Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            set -e
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
            docker logout
          '''
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh '''
          aws eks update-kubeconfig --region us-east-1 --name netflix-eks
          kubectl get nodes
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
          
          kubectl get pods
          kubectl get svc
        '''
      }
    }
  }
  
  post {
    always {
      sh '''
        echo "=== Docker images ==="
        docker images | head || true
      '''
      cleanWs()
    }
    success {
      echo 'Pipeline completed successfully.'
    }
    failure {
      echo 'Pipeline failed.'
    }
  }
}
