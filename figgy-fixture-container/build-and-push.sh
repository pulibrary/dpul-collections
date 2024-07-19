#!/bin/bash

./create-fixture-exports.sh
echo "Enter lastpass username:" 
read USERNAME
lpass login $USERNAME
export GHCR_TOKEN=$(lpass show "Shared-ITIMS-Passwords/dpul_collections_fixture_container_github_token" --notes)
echo $GHCR_TOKEN | docker login ghcr.io -u pulbot --password-stdin
docker buildx create --name multiarch --driver docker-container --use || true
docker buildx build --push --platform linux/arm64,linux/amd64 -t ghcr.io/pulibrary/dpul-collections:figgy-fixtures .
