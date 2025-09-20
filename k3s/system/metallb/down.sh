#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Removing additional configs"
kubectl delete -f $SCRIPT_DIR/config.yaml
echo "Removing main resources"
kubectl delete -k $SCRIPT_DIR
