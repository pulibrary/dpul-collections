#!/bin/bash

./create-fixture-exports.sh
echo "Enter lastpass username:" 
read USERNAME
lpass login $USERNAME
export CR_PAT=$(lpass show "Shared-ITIMS-Passwords/dpul_collections_fixture_container_github_token" --notes)
echo $CR_PAT | docker login ghcr.io -u pulbot --password-stdin
docker buildx create --name multiarch --driver docker-container --use || true
docker buildx build --push --platform linux/arm64,linux/amd64 -t ghcr.io/pulibrary/dpul-collections:figgy-fixtures .
