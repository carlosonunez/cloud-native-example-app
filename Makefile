SHELL := /usr/bin/env bash
MAKEFLAGS += --silent
APP_NAME=example-cloud-native-app

# Hide orphaned container warnings that can appear if docker-compose doesn't
# "down" entirely.
DOCKER_COMPOSE := docker-compose --log-level INFO
DOCKER_COMPOSE_CI := docker-compose --log-level INFO -f docker-compose.ci.yaml
DOCKER_COMPOSE_TERRAFORM := docker-compose --log-level INFO -f docker-compose.terraform.yaml

# Include our dotenv to Make's local scope so that we can access variables
# without shelling out.
include ./.env

.PHONY: build push \
	unit-setup unit-tests unit-teardown \
	integration-setup integration-deploy integration-tests integration-teardown \
	production-setup production-deploy

build: _decrypt_dotenv
build:
	for service in frontend backend; \
	do \
		dockerfile="$(PWD)/$${service}.Dockerfile"; \
		image_name="$(IMAGE_REPO)/$(APP_NAME)-$$service:$(COMMIT_SHA)"; \
		docker build -t "$$image_name" -f "$$dockerfile" .; \
	done

push: _decrypt_dotenv
push:
	docker login "$(IMAGE_REPO)" --username "$(IMAGE_REPO_USERNAME)" \
		--password "$(IMAGE_REPO_PASSWORD)" &&
		for service in frontend backend; \
		do \
			image_name="$(IMAGE_REPO)/$(APP_NAME)-$${service}:$(COMMIT_SHA)"; \
			docker push "$$image_name"; \
		done

unit-setup:
	>&2 echo "No setup for unit tests needed!"

unit-tests:
	$(DOCKER_COMPOSE) run --build --rm unit-tests-frontend && \
	$(DOCKER_COMPOSE) run --build --rm unit-tests-backend

unit-teardown:
	$(DOCKER_COMPOSE) down

# NOTE: integration-{setup,deploy,teardown}
#
# Since this project aims to be a complete example, we're rolling our own
# integration environment.
#
# Spinning up clusters ephemerally like this can become very expensive in time (it takes
# about eight minutes for an EKS cluser to become ready) and money (having every dev
# team spin up their own EKS clusters ephemerally like this gets expensive and becomes
# a bit of a nightmare for operations).
#
# In a real-world scenario, the integration test pipeline would likely be maintained by the
# Platform team. This hypothetical pipeline would look for a Helm chart at the root of the
# repo, automatically handle deploying it into an integration environment, and present
# the dev team's pipeline with a FQDN to the app and other metadata they might need
# to complete their tests.
integration-setup: decrypt_integration_dotenv
integration-setup:
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE) run --rm terraform-init &&
	$(DOCKER_COMPOSE) run --rm terraform-apply

integration-deploy: decrypt_integration_dotenv
integration-deploy:
	set -eo pipefail; \
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE) run --rm terraform-output kubeconfig > /tmp/kubeconfig; \
	host_name=$$($(DOCKER_COMPOSE) run --rm terraform-output 
	image_name="$(IMAGE_REPO)/$(APP_NAME):$(COMMIT_SHA)"; \
	$(HELM) upgrade \
		--kubeconfig /tmp/kubeconfig \
		--set image_name="$$image_name" \
		$(APP_NAME) \
		./chart

integration-tests: decrypt_integration_dotenv
integration-tests:
	export ENVIRONMENT=integration; \
	export APP_URL=https://$(APP_NAME).$(CLUSTER_FQDN); \
	$(DOCKER_COMPOSE) run --rm integration-tests;

integration-teardown: decrypt_integration_dotenv
integration-teardown:
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init &&
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-destroy

# NOTE: production-{setup,deploy}
# 
# Same caveats as the integration targets above. These would most likely be included in a pipeline
# maintained by Platform.
production-setup: decrypt_production_dotenv
production-setup:
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init &&
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-apply

production-deploy: decrypt_production_dotenv
production-deploy:
	set -eo pipefail; \
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE) run --rm terraform-output kubeconfig > /tmp/kubeconfig; \
	host_name=$$($(DOCKER_COMPOSE) run --rm terraform-output 
	frontend_image_name="$(IMAGE_REPO)/$(APP_NAME)-frontend:$(COMMIT_SHA)"; \
	backend_image_name="$(IMAGE_REPO)/$(APP_NAME)-backend:$(COMMIT_SHA)"; \
	$(HELM) upgrade \
		--kubeconfig /tmp/kubeconfig \
		--set frontend_image_name="$$frontend_image_name" \
		--set backend_image_name="$$backend_image_name" \
		$(APP_NAME) \
		./chart

encrypt_production_dotenv:
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_CI) run --rm encrypt-dotenv;

decrypt_production_dotenv:
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_CI) run --rm decrypt-dotenv;

encrypt_integration_dotenv:
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_CI) run --rm encrypt-dotenv;

decrypt_integration_dotenv:
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_CI) run --rm decrypt-dotenv;
