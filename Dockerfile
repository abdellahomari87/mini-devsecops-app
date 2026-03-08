FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/mini-devsecops-app.jar app.jar
CMD ["java", "-jar", "app.jar"]