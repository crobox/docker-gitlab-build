#!/usr/bin/env bash
set -Eeuo pipefail

MARATHON_FILE=
APP_ID=
if [ $# -eq 2 ]
  then
    MARATHON_FILE=$2
    APP_ID=$(cat ${MARATHON_FILE} | jq -r '.id')
elif [ $# -eq 3 ]
  then
    APP_ID=$2
    MARATHON_FILE=$3
  else
    echo "Don't know how to work with this arguments."
    exit -1
fi
MARATHON_URI=$1

max_deploy_time=${MAX_DEPLOYMENT_TIME-180}
echo "Running deployment for $APP_ID with file $MARATHON_FILE. Max time $max_deploy_time"
deployment_id=$(http --check-status PUT "${MARATHON_URI}/v2/apps/${APP_ID}" < "${MARATHON_FILE}" | jq -r '.deploymentId')
deployment_in_progress="alive"
echo "Created deployment with id $deployment_id"
current_deployment_time=0
while [[  ${deployment_in_progress} != "" && ${current_deployment_time} -lt ${max_deploy_time} ]]; do
    echo "Deployment running, waiting before retrying to check status."
    sleep 5
    current_deployment_time=$((current_deployment_time + 5))
    deployment_in_progress=$(http --check-status GET "${MARATHON_URI}/v2/deployments" | jq -c '.[] | select(.id | contains($deployment_id))?' --arg deployment_id "${deployment_id}")
done
if [[ ${current_deployment_time} -ge ${max_deploy_time} ]];then
    echo "Deployment exceeded maximum time of $max_deploy_time"
    exit -1
fi
echo "Deployment has finished"
