PACTICIPANT := "pactflow-provider"
GITHUB_REPO := "pactflow-provider"
PACT_CLI_DOCKER_VERSION?=latest
PACT_BROKER_BASE_URL?=https://omnia-bcd45bf9.pactflow.io
PACT_BROKER_TOKEN?=LYSUuLYgl_5khVLFyvTkdA

PACT_CLI_DOCKER_RUN_COMMAND?=docker run --rm -v /${PWD}:/${PWD} -w ${PWD} \
  -e PACT_BROKER_BASE_URL=${PACT_BROKER_BASE_URL} \
  -e PACT_BROKER_TOKEN=${PACT_BROKER_TOKEN} \
  pactfoundation/pact-cli:${PACT_CLI_DOCKER_VERSION}
PACT_BROKER_COMMAND=pact-broker
PACTFLOW_CLI_COMMAND=pactflow
PACT_BROKER_CLI_COMMAND:=${PACT_CLI_DOCKER_RUN_COMMAND} ${PACT_BROKER_COMMAND}
PACTFLOW_CLI_COMMAND:=${PACT_CLI_DOCKER_RUN_COMMAND} ${PACTFLOW_CLI_COMMAND}

## ====================
## Demo Specific Example Variables
## ====================
VERSION?=$(shell npx -y absolute-version)-$(shell git rev-parse --short HEAD)
BRANCH?=$(shell git rev-parse --abbrev-ref HEAD)
OAS_PATH=oas/swagger.yml
REPORT_PATH?=report.txt
REPORT_FILE_CONTENT_TYPE?=text/plain
VERIFIER_TOOL?=restassured

## ====================
## Only deploy from main
## ====================

ifeq ($(BRANCH),main)
	DEPLOY_TARGET=deploy
else
	DEPLOY_TARGET=no_deploy
endif

all: test

## ====================
## CI tasks
## ====================

ci:
	@if make test; then \
		EXIT_CODE=0 make publish_provider_contract; \
	else \
		EXIT_CODE=1 make publish_provider_contract; \
	fi;

PHONY: publish_provider_contract

publish_provider_contract:
	@echo "\n========== STAGE: publish-provider-contract (spec + results) ==========\n"
	${PACTFLOW_CLI_COMMAND} publish-provider-contract \
	  ${OAS_PATH} \
	  --provider ${PACTICIPANT} \
	  --provider-app-version ${VERSION} \
	  --branch ${BRANCH} \
	  --content-type application/yaml \
	  --verification-exit-code=${EXIT_CODE} \
	  --verification-results ${REPORT_PATH} \
	  --verification-results-content-type ${REPORT_FILE_CONTENT_TYPE}\
	  --verifier ${VERIFIER_TOOL}

delete_branch:
	@if [ -z "${BRANCH_NAME}" ]; then \
	  echo "Error: BRANCH_NAME is not set. Please provide the branch name to delete."; \
	  exit 1; \
	fi
	@"${PACT_CLI}" broker delete-branch \
	  --pacticipant ${PACTICIPANT} \
	  --branch ${BRANCH_NAME}

# Run the ci target from a developer machine with the environment variables
# set as if it was on GitHub Actions
# Use this for quick feedback when playing around with your workflows.
fake_ci: .env
	CI=true \
	GIT_COMMIT=`git rev-parse --short HEAD`+`date +%s` \
	GIT_BRANCH=`git rev-parse --abbrev-ref HEAD` \
	make ci

deploy_target: can_i_deploy $(DEPLOY_TARGET)

## =====================
## Build/test tasks
## =====================

test: .env
	./gradlew clean test -i

## =====================
## Deploy tasks
## =====================

deploy: can_i_deploy deploy_app

no_deploy:
	@echo "Not deploying as not on master branch"

can_i_deploy:
	@${PACT_BROKER_CLI_COMMAND} can-i-deploy \
	  --pacticipant ${PACTICIPANT} \
	  --version ${GIT_COMMIT} \
	  --to-environment Production \
	  --retry-while-unknown 6 \
	  --retry-interval 10

deploy_app: record_deployment
	@echo "Deploying to prod"

record_deployment:
	@${PACT_BROKER_CLI_COMMAND} record_deployment --pacticipant ${PACTICIPANT} --version ${VERSION} --environment production
