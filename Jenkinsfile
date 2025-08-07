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
        bat 'pip install -r requirements.txt'
      }
    }
    stage('Test') {
      steps {
        bat 'python -c "import app"'
      }
    }
    stage('Run (Dev)') {
      steps {
        bat 'start /b python app.py'
      }
    }
  }
}
