pipeline {
  agent any

  stages {
    stage('Clone') {
      steps {
        checkout scm
      }
    }
    stage('Install') {
      steps {
        sh 'pip install -r requirements.txt'
      }
    }
    stage('Test') {
      steps {
        sh 'python -c "import app"'
      }
    }
    stage('Run (Dev)') {
      steps {
        sh 'nohup python app.py &'
        // 필요하면 sleep으로 서버 띄워두고 접근 테스트 추가 가능
      }
    }
  }
}
