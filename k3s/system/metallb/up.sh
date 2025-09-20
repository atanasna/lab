#!/bin/bash
set -e

WAIT_TIMER=10
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Applying main MetalLB resources"
kubectl apply -k $SCRIPT_DIR

echo "Waiting(${WAIT_TIMER}s) for main resources to be ready ..."
sleep $WAIT_TIMER

echo "Applying additional configs"
kubectl apply -f $SCRIPT_DIR/config.yaml

echo "MetalLB deployment complete!"
