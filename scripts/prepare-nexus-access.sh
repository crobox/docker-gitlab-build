#!/usr/bin/env bash

: "${NEXUS_HOST:?Missing required NEXUS_HOST variable}"

mkdir -p ~/.sbt/0.13/plugins

cat << EOF > ~/.sbt/0.13/plugins/credentials.sbt
credentials += Credentials("Sonatype Nexus Repository Manager", "$NEXUS_HOST", System.getenv("NEXUS_USER"), System.getenv("NEXUS_PASS"))
EOF

cat << EOF > ~/.sbt/repositories
[repositories]
  local
  ivy-proxy-releases: https://$NEXUS_HOST/repository/maven-public/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
  maven-proxy-releases: https://$NEXUS_HOST/repository/maven-public/
EOF
