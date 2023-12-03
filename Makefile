SHELL := /usr/bin/env bash
MAKEFLAGS += --silent
APP_NAME=example-cloud-native-app

# Hide orphaned container warnings that can appear if docker-compose doesn't
# "down" entirely.
DOCKER_COMPOSE := docker-compose --log-level ERROR
DOCKER_COMPOSE_CI := docker-compose --log-level ERROR -f docker-compose.ci.yml
DOCKER_COMPOSE_TERRAFORM := docker-compose --log-level ERROR -f docker-compose.terraform.yaml
DOCKER_COMPOSE_AWS := docker-compose --log-level ERROR -f docker-compose.aws.yml
COMMIT_SHA := $(shell git rev-parse --short HEAD)
HELM := $(DOCKER_COMPOSE_CI) run --rm helm --kubeconfig /tmp/kubeconfig

# There's no other way to escape percent signs in Make (that I know of).
PERCENT := %

.PHONY: build push \
	unit-setup unit-tests unit-teardown \
	integration-setup integration-deploy integration-tests integration-teardown \
	production-setup production-deploy

build: decrypt_production_dotenv
build:
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	for service in frontend backend; \
	do \
		image_name="$$IMAGE_REPO/$(APP_NAME)-$$service:$(COMMIT_SHA)"; \
		docker build -t "$$image_name" --build-arg app="$$service" .; \
	done

push: decrypt_production_dotenv
push:
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	docker login "$$IMAGE_REPO" --username "$$IMAGE_REPO_USERNAME" \
		--password "$$IMAGE_REPO_PASSWORD" && \
		for service in frontend backend; \
		do \
			image_name="$$IMAGE_REPO/$(APP_NAME)-$${service}:$(COMMIT_SHA)"; \
			docker push "$$image_name"; \
		done

unit-setup:
	$(DOCKER_COMPOSE) up -d frontend backend

unit-tests:
	$(DOCKER_COMPOSE) run --rm unit-tests-frontend &&
	$(DOCKER_COMPOSE) run --rm unit-tests-backend

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
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init && \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-apply

integration-setup-preview: decrypt_integration_dotenv
integration-setup-preview:
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export ENVIRONMENT=integration; \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	env | grep AWS; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init && \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-plan

integration-deploy: decrypt_integration_dotenv write_kubeconfig_integration
integration-deploy:
	set -eo pipefail; \
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export ENVIRONMENT=integration; \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-output kubeconfig > /tmp/kubeconfig; \
	image_name_template="$$IMAGE_REPO/$(APP_NAME)-$(PERCENT)s:$(COMMIT_SHA)"; \
	$(HELM) upgrade \
		--set frontend_image_name="$$(printf "$$image_name_template" frontend)" \
		--set backend_image_name="$$(printf "$$image_name_template" backend)" \
		$(APP_NAME) \
		./chart

integration-tests: decrypt_integration_dotenv
integration-tests:
	export ENVIRONMENT=integration; \
	export APP_URL=https://$(APP_NAME).$(CLUSTER_FQDN); \
	$(DOCKER_COMPOSE) run --rm integration-tests;

integration-teardown: decrypt_integration_dotenv
integration-teardown:
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export ENVIRONMENT=integration; \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init && \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-destroy

# NOTE: production-{setup,deploy}
# 
# Same caveats as the integration targets above. These would most likely be included in a pipeline
# maintained by Platform.
production-setup: decrypt_production_dotenv
production-setup:
	export ENVIRONMENT=production; \
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init &&
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-apply

production-deploy: decrypt_production_dotenv write_kubeconfig_production
production-deploy:
	set -eo pipefail; \
	export ENVIRONMENT=production; \
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-output kubeconfig > /tmp/kubeconfig; \
	image_name_template="$$IMAGE_REPO/$(APP_NAME)-$(PERCENT)s:$(COMMIT_SHA)"; \
	$(HELM) upgrade \
		--set frontend_image_name="$$(printf "$$image_name_template" frontend)" \
		--set backend_image_name="$$(printf "$$image_name_template" backend)" \
		$(APP_NAME) \
		./chart

encrypt_production_dotenv:
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_CI) run --rm encrypt-env;

decrypt_production_dotenv:
	test -f $(PWD)/.env.production && exit 0; \
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_CI) run --rm decrypt-env;

encrypt_integration_dotenv:
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_CI) run --rm encrypt-env;

decrypt_integration_dotenv:
	test -f $(PWD)/.env.integration && exit 0; \
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_CI) run --rm decrypt-env;

write_kubeconfig_integration:
	rm -f /tmp/kubeconfig; \
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-output kubeconfig > /tmp/kubeconfig;

write_kubeconfig_production:
	rm /tmp/kubeconfig; \
	export ENVIRONMENT=production; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-output kubeconfig > /tmp/kubeconfig;

# NOTE: The directory we're using to cache AWS tokens is `mkdir`ed ahead of time to work around
# `EPERM` errors that occur with container engines that use sshfs to mount directories into the
# containerd VM, like Lima. This is still an open issue as of 2023-12-02.
# https://github.com/lima-vm/lima/issues/231
generate_temp_aws_credentials:
	mkdir -p $${TMPDIR:-/tmp}/.aws-sts-token-data; \
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	export AWS_SESSION_NAME=$(APP_NAME)-aws-session; \
	aws_session=$$($(DOCKER_COMPOSE_AWS) run --rm obtain-aws-session-credentials | sed -E 's/(^"|"$$)//'); \
	if test -z "$$aws_session"; \
	then >&2 echo "ERROR: Unable to receive creds from AWS with AK/SK provided." && exit 1; \
	fi; \
	echo -e "$$aws_session" | grep -Ev '^$$';
