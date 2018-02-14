#!/usr/bin/env bash
set -Eeuo pipefail

marathon_uri=$1
if [ $# -eq 2 ]
  then
    marathon_file=$2
    app_id=$(cat marathon_file | jq -r '.id')
elif [ $# -eq 3 ]
  then
    app_id=$2
    marathon_file=$3
  else
    echo "Don't know how to work with this arguments."
    exit -1
fi
max_deploy_time=${MAX_DEPLOYMENT_TIME-180}
echo "Running deployment for $appid with file $marathon_file. Max time $max_deploy_time"
deployment_id=$(http --check-status PUT "${marathon_uri}/v2/apps/${app_id}" < "${marathon_file}" | jq -r '.deploymentId')
deployment_in_progress="alive"
echo "Created deployment with id $deployment_id"
current_deployment_time=0
while [[  ${deployment_in_progress} != "" && ${current_deployment_time} -lt ${max_deploy_time} ]]; do
    echo "Deployment running, waiting before retrying to check status."
    sleep 5
    current_deployment_time=$((current_deployment_time + 5))
    deployment_in_progress=$(http --check-status GET "${marathon_uri}/v2/deployments" | jq -c '.[] | select(.id | contains($deployment_id))?' --arg deployment_id "${deployment_id}")
done
if [[ ${current_deployment_time} -ge ${max_deploy_time} ]];then
    echo "Deployment exceeded maximum time of $max_deploy_time"
    exit -1
fi
echo "Deployment has finished"
