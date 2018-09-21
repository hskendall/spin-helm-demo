CHART_NAME=$(shell cat chart/spin-helm-demo/Chart.yaml | yq -r .name)
CHART_VERSION=$(shell cat chart/spin-helm-demo/Chart.yaml | yq -r .version)

APP_VERSION ?= $(shell cat chart/spin-helm-demo/Chart.yaml | yq -r .appVersion)

CHART_BUCKET ?= spin-helm-demo-bucket-piyali
DOCKER_REPO ?= awsnerd/spin-helm-demo
SPINNAKER_API ?= http://localhost:9000

docker:
	docker build -t $(DOCKER_REPO):$(APP_VERSION) .
	docker tag $(DOCKER_REPO):$(APP_VERSION) $(DOCKER_REPO):latest

dockerpush: docker
	docker push $(DOCKER_REPO):$(APP_VERSION)
	docker push $(DOCKER_REPO):latest

compile:
	helm package chart/spin-helm-demo

upload:
	aws s3 cp $(CHART_NAME)-$(CHART_VERSION).tgz s3://$(CHART_BUCKET)/packages/
	aws s3 cp values/dev.yaml s3://$(CHART_BUCKET)/packagevalues/$(CHART_NAME)/dev.yaml
	aws s3 cp values/prod.yaml s3://$(CHART_BUCKET)/packagevalues/$(CHART_NAME)/prod.yaml

triggerdocker:
	curl -L -vvv -X POST \
		-k \
		-H"Content-Type: application/json" $(SPINNAKER_API)/gate/webhooks/webhook/spinnakerhelmdemo \
		-d '{"artifacts": [{"type": "docker/image", "name": "$(CHART_NAME)", "reference": "$(DOCKER_REPO):$(APP_VERSION)", "kind": "docker"}]}'

triggerchartviagithub:
	curl -L -vvv -X POST \
	 -k \ 
	 -H"content-type: application/json" http://localhost:9000/gate/webhooks/webhook/sample \ 
	 -d '{"artifacts":[{"type":"github/file","name":"spin-helm-demo-$(CHART_VERSION).tgz","reference":"https://api.github.com/repos/pkamra/spin-helm-demo/contents/spin-helm-demo-$(CHART_VERSION).tgz","kind":"github"}]}'

triggerchartvias3:
	curl -L -vvv -X POST \
		-k \
		-H"Content-Type: application/json" $(SPINNAKER_API)/gate/webhooks/webhook/spinnakerhelmdemo \
		-d '{"artifacts": [{"type": "s3/object", "name": "s3://$(CHART_BUCKET)/packages/spin-helm-demo-$(CHART_VERSION).tgz", "reference": "s3://$(CHART_BUCKET)/packages/spin-helm-demo-$(CHART_VERSION).tgz", "kind": "s3"}]}'