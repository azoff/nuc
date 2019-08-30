#!/usr/bin/env bash

set -e

kubectl get secret/nuc -o yaml >| ./secret.yaml