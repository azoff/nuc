#!/usr/bin/env bash

set -ex

docker run --rm --entrypoint htpasswd registry:2 -Bbn $1 $2 >> "${3:-registry/auth}/htpasswd"