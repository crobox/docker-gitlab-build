#!/usr/bin/env bash
set -e

: "${SSH_PRIVATE_KEY:?Missing required SSH_PRIVATE_KEY variable}"
: "${SSH_SERVER_HOSTKEYS:?Missing required SSH_SERVER_HOSTKEYS variable}"

mkdir -p ~/.ssh
# Tested with ssh-agent and ssh-add but since gitlab doesn't pass the SSH_AGENT_PID and SSH_AUTH_SOCK it's
# unusable in the other stages of the build
echo "${SSH_PRIVATE_KEY}" | tr -d '\r' > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
echo "${SSH_SERVER_HOSTKEYS}" > ~/.ssh/known_hosts

# Setup git access
git config --global user.email "${GITLAB_USER_EMAIL}"
git config --global user.name "${GITLAB_USER_NAME} (${CI_RUNNER_DESCRIPTION})"
git remote set-url --push origin $(echo "${CI_REPOSITORY_URL}" | perl -pe 's#.*@(.+?(\:\d+)?)/#git@\1:#')
