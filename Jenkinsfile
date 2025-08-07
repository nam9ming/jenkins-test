pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    // 이미지 빌드
                    bat 'docker build -t my-flask-app .'
                }
            }
        }
        stage('Stop & Remove Old Container') {
            steps {
                script {
                    // 이미 실행중이면 중지/삭제 (실패해도 무시)
                    bat 'docker stop flask-test || exit 0'
                    bat 'docker rm flask-test || exit 0'
                }
            }
        }
        stage('Run Docker Container') {
            steps {
                script {
                    bat 'docker run -d -p 5000:5000 --name flask-test my-flask-app'
                }
            }
        }
    }
}
