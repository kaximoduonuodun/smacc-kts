#!/bin/sh
set -e

# 支持 jar 或 war（tomcat 场景后面再说）
if [ -f /app/app.jar ]; then
  exec java ${JAVA_OPTS:-"-Xms256m -Xmx512m"} -jar /app/app.jar
elif [ -f /app/app.war ]; then
  exec java ${JAVA_OPTS:-"-Xms256m -Xmx512m"} -jar /app/app.war
else
  echo "no /app/app.jar or /app/app.war"
  exit 1
fi