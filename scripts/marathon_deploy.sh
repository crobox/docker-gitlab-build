#!/usr/bin/env bash
set -e

marathon_uri=$1
appid=$2
marathon_file=$3
echo "Running deployment for $appid with file $marathon_file"
deployment_id=$(http --check-status PUT ${marathon_uri}/v2/apps/${appid} < ${marathon_file} | jq -r '.deploymentId')
deployment_in_progress=${deployment_id}
echo "Created deployment with id $deployment_id"
while [[  ${deployment_in_progress} = *"${deployment_id}"*  ]]; do
    echo "Deployment running, waiting before retrying to check status."
    sleep 5
    deployment_in_progress=$(http --check-status GET ${marathon_uri}/v2/deployments)
done

echo "Deployment has finished"
