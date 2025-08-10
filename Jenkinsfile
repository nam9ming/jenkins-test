pipeline {
  agent any
  options { timestamps() }
  tools {
    jdk 'JDK11'                  // Global Tool에 등록한 JDK 이름
    sonarqubeScanner 'SQScanner' // Global Tool에 등록한 SonarScanner 이름
  }

  environment {
    // Kubernetes
    APP = 'myapp'                              // Deployment/Service/containers[].name
    NS  = 'dev'
    IMG = "my-flask-app:${BUILD_NUMBER}"       // Docker Desktop+k8s 공유 → 로컬 태그 사용

    // SonarQube
    SONAR_PROJECT_KEY = 'jenkins-test'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Docker Image') {
      steps { bat 'docker build -t %IMG% .' }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-local', variable: 'KCFG')]) {
          bat '''
            kubectl --kubeconfig=%KCFG% config current-context
            kubectl --kubeconfig=%KCFG% get nodes

            rem ensure namespace
            kubectl --kubeconfig=%KCFG% create ns %NS% 2>NUL

            rem apply manifests (idempotent)
            kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\deployment.yaml
            kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\service.yaml

            rem roll out new image
            kubectl --kubeconfig=%KCFG% -n %NS% set image deploy/%APP% %APP%=%IMG%
            kubectl --kubeconfig=%KCFG% -n %NS% rollout status deploy/%APP% --timeout=180s

            kubectl --kubeconfig=%KCFG% -n %NS% get svc %APP% -o wide
          '''
        }
      }
    }

    stage('Check tools') {
      steps {
        bat 'java -version'
        bat 'where sonar-scanner'
        bat 'jmeter -v'
      }
    }

    /* ---------- JMeter ---------- */
    stage('Test - JMeter') {
      steps {
        bat '''
          rmdir /S /Q jmeter-report 2>NUL
          jmeter -n -t tests\\smoke.jmx -l jmeter-results.jtl -e -o jmeter-report
        '''
        publishHTML(target: [
          reportDir: 'jmeter-report',
          reportFiles: 'index.html',
          reportName: 'JMeter Report',
          keepAll: true,
          alwaysLinkToLastBuild: true
        ])
        script {
          // 요약 JSON (Express/프론트에서 쓰기 좋게)
          def stats = readJSON file: 'jmeter-report/statistics.json'
          def t = stats['Total']
          def summary = [
            samples   : t.sampleCount,
            errorPct  : t.errorPercentage,
            avgMs     : t.meanResTime,
            p90Ms     : t.p90,
            throughput: t.throughput
          ]
          writeJSON file: 'jmeter-summary.json', json: summary, pretty: 2
        }
        archiveArtifacts artifacts: 'jmeter-results.jtl,jmeter-report/**,jmeter-summary.json', fingerprint: true
      }
    }

    /* ---------- SonarQube ---------- */
    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('MySonar') { // Manage Jenkins > System 에 등록한 서버 이름
          bat '''
            sonar-scanner ^
              -Dsonar.projectKey=%SONAR_PROJECT_KEY% ^
              -Dsonar.sources=. ^
              -Dsonar.host.url=%SONAR_HOST_URL% ^
              -Dsonar.login=%SONAR_AUTH_TOKEN%
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          def qg = waitForQualityGate() // SonarQube → Webhooks: http://<jenkins>/sonarqube-webhook/
          writeJSON file: 'sonar-gate.json', json: [status: qg.status], pretty: 2
          archiveArtifacts artifacts: 'sonar-gate.json', fingerprint: true
        }
      }
    }

    /* ---- (옵션) Express로 바로 푸시 ----
    stage('Publish to DevSecOps API') {
      when { expression { return false } } // 필요 시 true로
      steps {
        powershell '''
          $j1 = Get-Content jmeter-summary.json -Raw
          $j2 = Get-Content sonar-gate.json -Raw
          $body = @{ build=$env:BUILD_NUMBER; jmeter=($j1|ConvertFrom-Json); sonar=($j2|ConvertFrom-Json) } | ConvertTo-Json -Depth 6
          Invoke-RestMethod -Uri http://localhost:4000/api/devsecops/results -Method Post -ContentType 'application/json' -Body $body
        '''
      }
    }
    ---------------------------------- */
  }

  post {
    always { echo 'Pipeline finished.' }
  }
}
