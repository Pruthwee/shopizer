FROM maven:3.9.4-eclipse-temurin-17 AS builder

WORKDIR /workspace

COPY pom.xml .
COPY sm-core-model/pom.xml sm-core-model/
COPY sm-core-modules/pom.xml sm-core-modules/
COPY sm-core/pom.xml sm-core/
COPY sm-shop-model/pom.xml sm-shop-model/
COPY sm-shop/pom.xml sm-shop/

RUN mvn dependency:go-offline -B -q

COPY sm-core-model/src sm-core-model/src
COPY sm-core-modules/src sm-core-modules/src
COPY sm-core/src sm-core/src
COPY sm-shop-model/src sm-shop-model/src
COPY sm-shop/src sm-shop/src

RUN mvn clean package -DskipTests -pl sm-shop -am

FROM eclipse-temurin:11-jdk

WORKDIR /app

COPY --from=builder /workspace/sm-shop/target/shopizer.jar app.jar

RUN groupadd -r appuser && useradd -r -g appuser appuser

EXPOSE 8080

ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV SPRING_PROFILES_ACTIVE=prod

USER appuser

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
