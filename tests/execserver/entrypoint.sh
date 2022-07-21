#!/bin/bash

if [ -z "$NAMESPACE" ]; then
    echo "NAMESPACE is not set"
    exit -1
fi
if [ -z "$SERVICE_NAME" ]; then
    echo "SERVICE_NAME is not set"
    exit -1
fi
if [ -z "$TMUX_SESSION_NAME" ]; then
    echo "SERVICE_NAME is not set"
    exit -1
fi
if [ -z "$VALIDATION_SERVICES" ]; then
    echo "SERVICE_NAME is not set"
    exit -1
fi

# create port-forwarding for the service
tmux new-session \
    -d \
    -s "$TMUX_SESSION_NAME" \
    kubectl --insecure-skip-tls-verify -n ${NAMESPACE} port-forward svc/${SERVICE_NAME} 8070:8070

VALIDATION_SERVICES=$(sed -e "s/,/ /g" <<< "$VALIDATION_SERVICES")
echo $VALIDATION_SERVICES

code=0
# for services in VALIDATION_SERVICES echo
for service in $VALIDATION_SERVICES; do
    echo "Validating service: $service"
    rslt=$(curl -X GET http://localhost:8070/job/$service)
    errorMessage=$(jq .Error <<< $rslt | sed -e 's/"//g' -e 's/\\//g')
    statusCode=$(jq .Status <<< $rslt)
    if [ "$errorMessage" == "Unknown service $service" ]; then
        echo "Status code is: $statusCode"
        echo "Error: $errorMessage"
        code=-1
    else
        echo "Check for service [ $service ] passed"
    fi
done

tmux kill-session -t $TMUX_SESSION_NAME

exit $code



#kubectl -n $NAMESPACE port-forward svc/$SERVICE_NAME 8080:8080 &
