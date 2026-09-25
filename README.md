[![CI](https://github.com/AleksVedenyev/project-devops-deploy/actions/workflows/ci.yml/badge.svg)](https://github.com/AleksVedenyev/project-devops-deploy/actions/workflows/ci.yml)

# Project DevOps Deploy

Bulletin board service.

## Fork policy

This upstream repository is read-only. We do not review or merge pull requests and we do not accept infrastructure changes (Dockerfiles, Ansible roles, CI/CD workflows, etc.). To experiment or extend the project, fork it and work inside your own repository.

## Project overview

This is a bulletin board application with:
* **Spring Boot** backend
* **React Admin + Vite** frontend
* **Image uploads** stored in the local filesystem in dev and in S3-compatible storage in prod

The default dev profile uses an in-memory H2 database and seeds 10 sample bulletins through `DataInitializer`, so the API works immediately after startup.

API documentation is available via Swagger UI:
* **Local:** http://localhost:8080/swagger-ui/index.html
* **Production:** http://aleks-devops.ru

## Deployment

The application is deployed to a production server and available at:
* **Domain:** http://aleks-devops.ru
* **API:** http://aleks-devops.ru/api/bulletins
* **Swagger UI:** http://aleks-devops.ru/swagger-ui/index.html

### Deploying

Deployment is done via Ansible and can be triggered with a single command:

```bash
make deploy
```

By default, this deploys the `latest` image tag.

To deploy or roll back to a specific version, pass the immutable SHA-based tag published by CI:

```bash
make deploy IMAGE_TAG=<git-commit-sha>
```

Each CI run on `main` publishes the image under two tags: `latest` and the commit SHA (`aleksved/project-devops-deploy:<sha>`). The SHA tag is never overwritten, so it can be used to redeploy an exact previous build if a rollback is needed.

### Vault password file

Ansible uses an encrypted `vault.yml` for sensitive variables. To run deployment locally, create a password file in the project root:

```bash
echo "your-secret-password" > vault-password-file
chmod 600 vault-password-file
```
The file is ignored by git and is not committed to the repository. If you want to use a different path, update the --vault-password-file argument in Makefile.

## Environment variables

Key variables are read directly by Spring Boot (see `src/main/resources/application.yml` and `application-prod.yml` for defaults):

| Variable | Description | Default |
| :--- | :--- | :--- |
| `SPRING_PROFILES_ACTIVE` | Active Spring profile (dev, prod, etc.) | `dev` |
| `SPRING_DATASOURCE_URL` | JDBC URL for PostgreSQL in prod | `jdbc:postgresql://localhost:5432/bulletins` |
| `SPRING_DATASOURCE_USERNAME` | DB username | `postgres` |
| `SPRING_DATASOURCE_PASSWORD` | DB password | `postgres` |
| `STORAGE_S3_BUCKET` | Bucket name for bulletin images | *empty* |
| `STORAGE_S3_REGION` | Region for the S3-compatible storage | *empty* |
| `STORAGE_S3_ENDPOINT` | Optional custom endpoint | *empty* |
| `STORAGE_S3_ACCESSKEY` | Access key ID | *empty* |
| `STORAGE_S3_SECRETKEY` | Secret key | *empty* |
| `STORAGE_S3_CDNURL` | Optional public CDN prefix | *empty* |
| `MANAGEMENT_SERVER_PORT` | Port for Spring Actuator endpoints | `9090` |
| `JAVA_OPTS` | Extra JVM parameters | *empty* |

All other variables supported by Spring Boot can be overridden the same way.

## Requirements

* JDK 21+
* Gradle 9.2.1
* PostgreSQL (only if you run the prod profile with an external database)
* Make
* NodeJS 20+

## Running locally

### Backend (dev profile)

From the repository root:

```bash
make run
```

Useful endpoints:
* **GET** http://localhost:8080/api/bulletins
* **GET** http://localhost:8080/api/bulletins?page=1&perPage=9&sort=createdAt&order=DESC&state=PUBLISHED&search=laptop
* **Swagger UI:** http://localhost:8080/swagger-ui/index.html

`/api/bulletins` accepts pagination (`page`, `perPage`), sorting (`sort`, `order`) and filters (`state`, `search`). Filters are processed via JPA Specifications so the same contract is available to the React Admin frontend.

### Frontend (dev build)

In a second terminal:

```bash
cd frontend
make install
make start
```

The Vite dev server proxies `/api` requests to http://localhost:8080, so keep the backend running.

### Production profile on a single host

Export the environment variables from the table above (DB access, S3 storage, `JAVA_OPTS`, etc.). The defaults in `application-prod.yml` show the exact property names if you need to double-check.

Build and launch the backend:

```bash
make build
java -jar build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar
```

The frontend can be served either from the same JVM or separately via static hosting/CDN once `frontend/dist` is uploaded.

`JAVA_OPTS` can be used to control heap size, GC, or add any `-D` system properties without editing the manifest.

#### Build and serve from the Java app

Build the production bundle:

```bash
cd frontend
make install
make build
```

Copy the compiled assets into Spring Boot’s static resources:

```bash
rm -rf src/main/resources/static
mkdir -p src/main/resources/static
cp -R frontend/dist/* src/main/resources/static/
```

Restart the backend:

```bash
make run
```

Then open http://localhost:8080/ — the React app will be served directly by the Java application.

## Running in Docker

Build the minimal production-ready Docker image using the multi-stage Dockerfile:

```bash
docker build -t project-devops-deploy .
```

Run the application locally with the default development profile:

```bash
docker run --rm -p 8080:8080 project-devops-deploy:latest
```

The application interface and API will be available at http://localhost:8080.

### Advanced configuration

You can pass JVM flags and Spring profiles via `JAVA_OPTS` or environment variables:

```bash
docker run --rm -p 8080:8080 \
  -e JAVA_OPTS="-Xms256m -Xmx512m -Dspring.profiles.active=prod" \
  project-devops-deploy:latest
```

Useful JVM options:
* `-Xms`/`-Xmx` — set memory limits inside the container
* `-XX:+UseContainerSupport` / `-XX:ActiveProcessorCount` — respect cgroup limits
* `-Dspring.profiles.active=prod` — switch the profile without recompiling
* `-Dlogging.level.root=INFO` or Spring environment variables (`SPRING_DATASOURCE_URL`, `STORAGE_S3_BUCKET`, etc.) — configure external services

### Monitoring / management ports

Application traffic still uses port 8080 by default. Actuator endpoints (health, metrics, Prometheus scrape, logfile) listen on `MANAGEMENT_SERVER_PORT` (defaults to 9090 for every profile).

If your deployment does not include Prometheus/Grafana yet, you can ignore the management port entirely; the application starts normally even if nothing scrapes `/actuator`.

When monitoring is enabled, expose both ports, for example:

```bash
docker run -p 8080:8080 -p 9090:9090 ...
```

Health probes are available at:
* `/actuator/health/liveness`
* `/actuator/health/readiness`

### Actuator endpoints (local check)

With the app running locally (`make run`), the management port defaults to http://localhost:9090.

Useful URLs:
* http://localhost:9090/actuator
* http://localhost:9090/actuator/health
* http://localhost:9090/actuator/health/liveness
* http://localhost:9090/actuator/health/readiness
* http://localhost:9090/actuator/metrics
* http://localhost:9090/actuator/metrics/http.server.requests
* http://localhost:9090/actuator/prometheus
* http://localhost:9090/actuator/logfile

Override the host/port with `MANAGEMENT_SERVER_PORT` if you changed it.

## Logging

The backend writes structured JSON events to `stdout` via `src/main/resources/logback-spring.xml`. Every record contains timestamp, app, environment, instance, logger, thread, message arguments, MDC, and stack traces so Promtail/Loki (or any log shipper) can parse them without extra processing.

Container runtimes should forward `stdout`/`stderr` to your logging pipeline. Avoid redirecting logs to files unless your platform explicitly demands it.

## Image upload

### Local checks

Dev profile:
* Backend uses in-memory H2
* Image storage uses the local filesystem under `/tmp/bulletin-images`

Steps:
1. Start the backend: `make run`
2. Start the frontend dev server: `cd frontend && npm install && npm run dev`
3. In React Admin, create or edit a bulletin and upload an image
4. Verify that the preview loads via the generated `imageUrl`
5. Check backend logs or `/tmp/bulletin-images` for the uploaded file

### Production / S3

In production:
1. Configure the S3-related environment variables from the table above
2. Deploy the backend
3. Upload an image for a bulletin
4. Verify that the response from `/api/files/upload` contains a non-empty key
5. Verify that the image is shown in the bulletin view
6. Verify that the object exists in the S3 bucket

### S3 bucket setup

The application stores uploaded bulletin images in S3-compatible object storage.

If you do not automate bucket creation with IaC, create it manually in Yandex Cloud Console:
1. Open Object Storage in Yandex Cloud.
2. Create a bucket with a unique name.
3. Choose the region that matches your deployment.
4. Create an access key / secret key pair for the service account.
5. Export the required environment variables for the prod profile:
    - STORAGE_S3_BUCKET
    - STORAGE_S3_REGION
    - STORAGE_S3_ENDPOINT if you use a custom S3 endpoint
    - STORAGE_S3_ACCESSKEY
    - STORAGE_S3_SECRETKEY
    - STORAGE_S3_CDNURL if you serve files through CDN
7. Verify file upload in the application UI and make sure the uploaded object appears in the bucket.
