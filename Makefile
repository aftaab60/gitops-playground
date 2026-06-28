MINIKUBE_PROFILE ?= minikube

# ── Setup ────────────────────────────────────────────────────────────────────

## Create the Flutter project skeleton (run once before anything else)
init-frontend:
	flutter create --platforms=web frontend
	cd frontend && flutter pub get
	@echo "Flutter project created. Now run: make build-frontend"

## Download Go dependencies
init-api:
	cd api && go mod tidy

# ── Build ─────────────────────────────────────────────────────────────────────

## Build the Go API Docker image
build-api:
	cd api && go mod tidy
	docker build -t gitops-tracker-api:dev ./api

## Build the Flutter web app, then package into an nginx Docker image
build-frontend:
	cd frontend && flutter build web --release
	docker build -t gitops-tracker-frontend:dev ./frontend

## Build both images
build: build-api build-frontend

# ── Minikube ──────────────────────────────────────────────────────────────────

## Load locally built images into minikube (skips Docker Hub pull)
load-images:
	minikube image load gitops-tracker-api:dev --profile $(MINIKUBE_PROFILE)
	minikube image load gitops-tracker-frontend:dev --profile $(MINIKUBE_PROFILE)

# ── Deploy ───────────────────────────────────────────────────────────────────

## Apply the dev overlay (namespace gitops-dev)
deploy-dev:
	kubectl apply -k manifests/dev

## Apply the prod overlay (namespace gitops-prod)
deploy-prod:
	kubectl apply -k manifests/prod

## Preview what dev overlay will produce (dry-run, no cluster changes)
diff-dev:
	kubectl diff -k manifests/dev

# ── Port-forward (run each in a separate terminal) ────────────────────────────

## Forward the Go API to localhost:8080
pf-api:
	kubectl port-forward -n gitops-dev svc/api-service 8080:8080

## Forward the Flutter frontend to localhost:3000
pf-frontend:
	kubectl port-forward -n gitops-dev svc/frontend-service 3000:80

# ── Observe ──────────────────────────────────────────────────────────────────

## Watch all pods in gitops-dev
watch-dev:
	kubectl get pods -n gitops-dev -w

## Show logs from the API pod
logs-api:
	kubectl logs -n gitops-dev -l app=api -f

# ── Teardown ──────────────────────────────────────────────────────────────────

## Delete the dev environment
clean-dev:
	kubectl delete -k manifests/dev --ignore-not-found

## Delete the prod environment
clean-prod:
	kubectl delete -k manifests/prod --ignore-not-found

.PHONY: init-frontend init-api build-api build-frontend build load-images \
        deploy-dev deploy-prod diff-dev pf-api pf-frontend \
        watch-dev logs-api clean-dev clean-prod
