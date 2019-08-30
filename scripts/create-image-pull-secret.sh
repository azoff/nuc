#!/usr/bin/env bash

set -ex

kubectl create secret generic dockerconfigjson \
    --from-file=.dockerconfigjson=$(echo ~/.docker/config.json) \
    --type=kubernetes.io/dockerconfigjson