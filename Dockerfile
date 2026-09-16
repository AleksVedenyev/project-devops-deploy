FROM node:20-alpine AS frontend_builder
WORKDIR /app
COPY frontend/ .
RUN npm ci
RUN npm run build

FROM eclipse-temurin:21-jdk AS backend_builder
WORKDIR /app
COPY . .
RUN rm -rf src/main/resources/static
RUN mkdir -p src/main/resources/static
COPY --from=frontend_builder /app/dist ./src/main/resources/static/
RUN ./gradlew build

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=backend_builder /app/build/libs/*-SNAPSHOT.jar ./app.jar
CMD ["java", "-jar", "./app.jar"]
