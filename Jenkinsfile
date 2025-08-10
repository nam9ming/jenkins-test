pipeline {
  agent any
  options { timestamps() }

  environment {
    APP = 'myapp'                    // Deployment/Service 이름
    NS  = 'dev'
    IMG = "my-flask-app:${BUILD_NUMBER}"  // 로컬 빌드 태그 (레지스트리 푸시 불필요)
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Docker Image') {
      steps {
        bat 'docker build -t %IMG% .'
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        // Jenkins > Credentials > Secret file 로 올린 kubeconfig 사용
        withCredentials([file(credentialsId: 'kubeconfig-local', variable: 'KCFG')]) {
          bat '''
          kubectl --kubeconfig=%KCFG% config current-context
          kubectl --kubeconfig=%KCFG% get nodes

          rem 네임스페이스 없으면 생성
          kubectl --kubeconfig=%KCFG% create ns %NS% 2>NUL

          rem 예전 데모(hello) 리소스가 있으면 정리(없으면 무시)
          kubectl --kubeconfig=%KCFG% -n %NS% delete deploy/hello svc/hello 2>NUL

          rem 최초 1회: 매니페스트 적용(그 후에도 재적용 안전)
          kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\deployment.yaml
          kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\service.yaml

          rem 새로 빌드한 이미지를 Deployment에 반영(롤링 업데이트)
          kubectl --kubeconfig=%KCFG% -n %NS% set image deploy/%APP% %APP%=%IMG% --record

          kubectl --kubeconfig=%KCFG% -n %NS% rollout status deploy/%APP% --timeout=180s
          kubectl --kubeconfig=%KCFG% -n %NS% get svc %APP% -o wide
          '''
        }
      }
    }
  }
}
