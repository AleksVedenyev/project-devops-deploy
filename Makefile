IMAGE_TAG ?= latest

docker-build:
	docker build -t project-devops-deploy .

docker-run-dev:
	docker run --rm -p 8080:8080 project-devops-deploy:latest

deploy:
	ansible-playbook deploy.yml -i inventory.yml -e "image_tag=$(IMAGE_TAG)"

test:
	./gradlew test

start: run

run:
	./gradlew bootRun

update-gradle:
	./gradlew wrapper --gradle-version 9.2.1

update-deps:
	./gradlew versionCatalogUpdate

install:
	./gradlew dependencies

build:
	./gradlew build

lint:
	./gradlew spotlessCheck

lint-fix:
	./gradlew spotlessApply

.PHONY: build
