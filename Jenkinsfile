// Runs in the home lab's Jenkins, in one pod running the Raku CI image built
// from raku-ci/ in the devops repo. When every stage passes, Jenkins reports
// the continuous-integration/jenkins/branch status, which starts
// .github/workflows/ci.yml on the same commit.

def buildPod = '''
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - name: ci
        image: harbor.home.gregdonald.com/raku/ci:latest
        imagePullPolicy: Always
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 4Gi
'''

pipeline {
  agent {
    kubernetes {
      defaultContainer 'ci'
      yaml buildPod
    }
  }

  options {
    disableConcurrentBuilds(abortPrevious: true)
    timeout(time: 60, unit: 'MINUTES')
  }

  // A failing test stage marks the build failed and the stages after it
  // still run, so one run reports every failure.
  stages {
    stage('dependencies') {
      steps {
        sh 'zef install --/test --test-depends --deps-only .'
      }
    }

    stage('prove6') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh './test.raku prove6'
        }
      }
    }

    stage('behave') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh './test.raku behave --coverage --coverage-branch --coverage-format html --coverage-output coverage'
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
        }
      }
    }
  }
}
