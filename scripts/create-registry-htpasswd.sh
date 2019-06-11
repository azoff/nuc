#!/usr/bin/env bash

set -ex

kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=$(echo ~/.docker/config.json) \
    --type=kubernetes.io/dockerconfigjson