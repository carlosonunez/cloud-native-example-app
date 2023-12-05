SHELL := /usr/bin/env bash
MAKEFLAGS += --silent
APP_NAME := example-cloud-native-app
APP_NAMESPACE := $(APP_NAME)

# Hide orphaned container warnings that can appear if docker-compose doesn't
# "down" entirely.
TMPDIR ?= /tmp
DOCKER_COMPOSE := docker-compose --log-level ERROR
DOCKER_COMPOSE_CI := docker-compose --log-level ERROR -f docker-compose.ci.yml
DOCKER_COMPOSE_TERRAFORM := docker-compose --log-level ERROR -f docker-compose.terraform.yaml
DOCKER_COMPOSE_AWS := docker-compose --log-level ERROR -f docker-compose.aws.yml
DOCKER_COMPOSE_SEC := docker-compose --log-level ERROR -f docker-compose.security.yaml
COMMIT_SHA := $(shell git rev-parse --short HEAD)
HELM := $(DOCKER_COMPOSE_CI) run --rm helm --kubeconfig /tmp/kubeconfig
KUBECTL := kubectl --kubeconfig $(TMPDIR)/kubeconfig
KUBECTL_IN_APP_NS := $(KUBECTL) --namespace $(APP_NAMESPACE)
HELM_IN_APP_NS := $(HELM) --namespace $(APP_NAMESPACE)

# You'll need to add an entry to /etc/hosts to hit this.
HOSTNAME := example.com

# There's no other way to escape percent signs in Make (that I know of).
PERCENT := %

.PHONY: build push \
	unit-setup unit-tests unit-teardown \
	security-scan-image \
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

security-scan-image:
	for service in frontend backend; \
	do \
		export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
		export APP_IMAGE="$$IMAGE_REPO/$(APP_NAME)-$${service}:$(COMMIT_SHA)"; \
		$(DOCKER_COMPOSE_SEC) run --rm --build scan-image; \
	done;

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
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	export ENVIRONMENT=integration; \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init && \
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-apply && \
	$(MAKE) configure-cluster-integration

configure-cluster-integration: write_kubeconfig_integration
configure-cluster-integration:
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	$(KUBECTL) get ns $(APP_NAMESPACE) &>/dev/null || $(KUBECTL) create ns $(APP_NAMESPACE) && \
	$(KUBECTL_IN_APP_NS) get secret registry &>/dev/null || \
			$(KUBECTL_IN_APP_NS) create secret docker-registry registry \
		--docker-server="$$IMAGE_REPO" \
		--docker-username="$$IMAGE_REPO_USERNAME" \
		--docker-password="$$IMAGE_REPO_PASSWORD" && \
	$(KUBECTL_IN_APP_NS) patch serviceaccount default \
		-p '{"imagePullSecrets":[{"name":"registry"}]}' && \
	$(HELM) upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace


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
	image_name_template="$$IMAGE_REPO/$(APP_NAME)-$(PERCENT)s:$(COMMIT_SHA)"; \
	$(HELM_IN_APP_NS) upgrade --install \
		--set frontend_image_name="$$(printf "$$image_name_template" frontend)" \
		--set backend_image_name="$$(printf "$$image_name_template" backend)" \
		--set ingress.hostName="$(HOSTNAME)" \
		$(APP_NAME) \
		./chart

integration-tests: decrypt_integration_dotenv write_kubeconfig_integration
integration-tests:
	lb=$$($(KUBECTL) get svc -n ingress-nginx ingress-nginx-controller \
		 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	if test -z "$$lb"; \
	then \
		>&2 echo "ERROR: Couldn't find ingress-nginx LB."; \
		exit 1; \
	fi; \
	export ENVIRONMENT=integration; \
	export FQDN="$(APP_NAME).$(HOSTNAME)"; \
	export IP=$$(host -4 "$$lb" | awk '{print $$NF}' | sort -R | tail -1); \
	export BACKEND_URL="$${FRONTEND_URL}/backend"; \
	$(DOCKER_COMPOSE) run --rm integration-tests;

# NOTE: We need to delete the nginx ingress controller before we delete the
# cluster. Otherwise, the load balancer that it creates will reside in the VPC
# and prevent the Terraform destroy from completing.
integration-teardown: decrypt_integration_dotenv write_kubeconfig_integration
integration-teardown:
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export ENVIRONMENT=integration; \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	$(HELM) uninstall ingress-nginx; \
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
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-init &&
	$(DOCKER_COMPOSE_TERRAFORM) run --rm terraform-apply &&
	$(MAKE) configure-cluster-production;

configure-cluster-production: write_kubeconfig_production
configure-cluster-production:
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	$(KUBECTL) create ns $(APP_NAMESPACE) && \
	$(KUBECTL) create secret docker-registry registry \
		--docker-server="$$IMAGE_REPO" \
		--docker-username="$$IMAGE_REPO_USERNAME" \
		--docker-password="$$IMAGE_REPO_PASSWORD" &&
	$(KUBECTL_IN_APP_NS) patch serviceaccount default \
		-p '{"imagePullSecrets":[{"name":"docker-registry"}]}' && \
	$(HELM) upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

production-deploy: decrypt_production_dotenv write_kubeconfig_production
production-deploy:
	set -eo pipefail; \
	export ENVIRONMENT=production; \
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	image_name_template="$$IMAGE_REPO/$(APP_NAME)-$(PERCENT)s:$(COMMIT_SHA)"; \
	$(HELM_IN_APP_NS) upgrade --install \
		--set frontend_image_name="$$(printf "$$image_name_template" frontend)" \
		--set backend_image_name="$$(printf "$$image_name_template" backend)" \
		--set ingress.hostName="$(HOSTNAME)" \
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
	export $$(grep -Ev '^#' "$(PWD)/.env.integration" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	export ENVIRONMENT=integration; \
	export CLUSTER_NAME=$$($(DOCKER_COMPOSE_TERRAFORM) run --rm terraform output -raw cluster_name) || exit 1; \
	$(DOCKER_COMPOSE_AWS) run --rm update-eks-kubeconfig; \

write_kubeconfig_production:
	export $$(grep -Ev '^#' "$(PWD)/.env.production" | xargs -0); \
	export $$($(MAKE) generate_temp_aws_credentials) || exit 1; \
	export ENVIRONMENT=production; \
	export CLUSTER_NAME=$$($(DOCKER_COMPOSE_TERRAFORM) run --rm terraform output -raw cluster_name) || exit 1; \
	$(DOCKER_COMPOSE_AWS) run --rm update-eks-kubeconfig; \

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
