# Fixture Container

This directory contains a Dockerfile for publishing a Solr image pre-loaded with fixtures for our DPUL-Collections tech experiments, so we don't have to mess with indexing for those tests.

You can run this container like so:

`docker run -p 8983:8983 ghcr.io/pulibrary/dpul-collections:fixtures-v1`

## Build Instructions

1. `bundle install`
1. `bundle exec generate-fixtures`
    * This is a separate process because it takes a long time, and we don't want the docker build to have to do it for every rebuild.
1. `export CR_PAT=$(lpass show dpul_collections_fixture_container_github_token --notes)`
1. `echo $CR_PAT | docker login ghcr.io -u pulbot --password-stdin`
1. `docker buildx create --name multiarch --driver docker-container --use`
1. `docker buildx build --push --platform linux/arm64,linux/amd64 -t ghcr.io/pulibrary/dpul-collections:fixtures-v1 .`

## Regenerate Cached Files

Delete cached-collection-manifest.json and figgy_manifest_fixtures, then follow the directions above if you want a full from-scratch rebuild.
