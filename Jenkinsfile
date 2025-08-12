pipeline {
  agent any
  options { timestamps() }
  tools {
    jdk 'JDK11'   // SonarScanner는 tool() 스텝으로 resolve
  }

  environment {
    // Kubernetes
    APP = 'myapp'
    NS  = 'dev'
    IMG = "my-flask-app:${BUILD_NUMBER}"

    // SonarQube
    SONAR_PROJECT_KEY = 'jenkins-test'
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
        withCredentials([file(credentialsId: 'kubeconfig-local', variable: 'KCFG')]) {
          bat '''
            kubectl --kubeconfig=%KCFG% config current-context
            kubectl --kubeconfig=%KCFG% get nodes
            kubectl --kubeconfig=%KCFG% create ns %NS% 2>NUL
            kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\deployment.yaml
            kubectl --kubeconfig=%KCFG% -n %NS% apply -f k8s\\service.yaml
            kubectl --kubeconfig=%KCFG% -n %NS% set image deploy/%APP% %APP%=%IMG%
            kubectl --kubeconfig=%KCFG% -n %NS% rollout status deploy/%APP% --timeout=180s
            kubectl --kubeconfig=%KCFG% -n %NS% get svc %APP% -o wide
          '''
        }
      }
    }

    stage('Resolve tools') {
      steps {
        script {
          env.SCANNER_HOME = tool name: 'SQScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
        }
      }
    }

    stage('Check tools') {
      steps {
        bat 'java -version'
        bat '"%SCANNER_HOME%\\bin\\sonar-scanner.bat" -v'
        bat 'docker version'     // ✅ JMeter는 Docker로 실행하므로 docker만 확인
      }
    }

    /* ---------- JMeter (Docker 컨테이너로 실행) ---------- */
    stage('Test - JMeter') {
      steps {
        // 결과 디렉토리 준비
        bat """
          if exist jmeter_%BUILD_NUMBER% rmdir /S /Q jmeter_%BUILD_NUMBER% 2>NUL
          mkdir jmeter_%BUILD_NUMBER%
        """

        // ✅ 컨테이너에서 테스트 수행 (워크스페이스를 /tests로 마운트)
        bat """
          docker run --rm -v "%CD%:/tests" -w /tests alpine/jmeter:5.6.3 ^
            -n -t tests/smoke.jmx ^
            -l jmeter_%BUILD_NUMBER%/results.jtl ^
            -e -o jmeter_%BUILD_NUMBER%/html
        """

        // HTML 리포트 퍼블리시 (Publish HTML Reports 플러그인 필요)
        publishHTML(target: [
          reportDir: "jmeter_${env.BUILD_NUMBER}/html",
          reportFiles: 'index.html',
          reportName: 'JMeter Report',
          keepAll: true,
          alwaysLinkToLastBuild: true
        ])

        // 통계 요약(JSON) 추출 (Pipeline Utility Steps 플러그인 필요)
        script {
          def stats = readJSON file: "jmeter_${env.BUILD_NUMBER}/html/statistics.json"
          def t = stats['Total'] ?: stats['ALL'] ?: stats
          def summary = [
            samples   : t.sampleCount,
            errorPct  : t.errorPercentage,
            avgMs     : t.meanResTime,
            p90Ms     : t.p90,
            throughput: t.throughput
          ]
          writeJSON file: 'jmeter-summary.json', json: summary, pretty: 2
        }

        // 아티팩트 보존(백엔드에서 읽기 용이)
        archiveArtifacts artifacts: "jmeter_${env.BUILD_NUMBER}/**,jmeter-summary.json", fingerprint: true
      }
    }

    /* ---------- SonarQube ---------- */
    stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('MySonar') {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
            script {
            // Jenkins 잡 이름을 Sonar 프로젝트 키로 (허용문자만 남기고 치환)
            def pk = env.JOB_NAME.replaceAll('[^A-Za-z0-9._-]', '-')
            bat "\"${tool 'SQScanner'}\\bin\\sonar-scanner.bat\" " +
              "-Dsonar.projectKey=${pk} " +
              "-Dsonar.projectName=${pk} " +
              "-Dsonar.sources=. " +
              "-Dsonar.token=%SONAR_TOKEN% " +
              "-Dsonar.host.url=http://localhost:9000"
            }
        }
        }
    }
    }


    stage('Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          script {
            def qg = waitForQualityGate()
            writeJSON file: 'sonar-gate.json', json: [status: qg.status], pretty: 2
          }
          archiveArtifacts artifacts: 'sonar-gate.json', fingerprint: true
        }
      }
    }

    /* ---- (옵션) Express API로 즉시 푸시 ----
    stage('Publish to DevSecOps API') {
      when { expression { return false } } // 필요 시 true로 변경
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
