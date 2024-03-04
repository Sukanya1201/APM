# Build application stage
FROM maven:3.8.5-jdk-11 as builder

WORKDIR /usr/src/java-code
RUN git clone https://github.com/spring-projects/spring-petclinic
WORKDIR /usr/src/java-code/spring-petclinic
RUN mvn -q -B package -DskipTests

RUN mkdir /usr/src/java-app
RUN cp -v /usr/src/java-code/spring-petclinic/target/*.war /usr/src/java-app/app.war

# Build the agent
ARG JAVA_AGENT_BRANCH=main
ARG JAVA_AGENT_REPO=elastic/apm-agent-java

WORKDIR /usr/src/java-agent-code
RUN curl -L https://github.com/$JAVA_AGENT_REPO/archive/$JAVA_AGENT_BRANCH.tar.gz | tar --strip-components=1 -xz

RUN mvn -q -B package -DskipTests

RUN export JAVA_AGENT_BUILT_VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec) \
    && cp -v /usr/src/java-agent-code/elastic-apm-agent/target/elastic-apm-agent-${JAVA_AGENT_BUILT_VERSION}.jar /usr/src/java-app/elastic-apm-agent.jar

# Final image
FROM tomcat:9.0.54-jdk11-openjdk

WORKDIR /usr/local/tomcat/webapps

COPY --from=builder /usr/src/java-app/app.war ./petclinic.war

RUN mkdir /usr/local/tomcat/elastic-apm-agent
COPY --from=builder /usr/src/java-app/elastic-apm-agent.jar /usr/local/tomcat/elastic-apm-agent/elastic-apm-agent.jar

ENV JAVA_OPTS="-javaagent:/usr/local/tomcat/elastic-apm-agent/elastic-apm-agent.jar ${JAVA_OPTS}"

EXPOSE 8080

CMD ["catalina.sh", "run"]
