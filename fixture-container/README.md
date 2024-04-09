# Instructions

1. `bundle install`
1. `bundle exec generate-fixtures`
    * This is a separate process because it takes a long time, and we don't want the docker build to have to do it for every rebuild.
1. `docker build . -t dpul-collection-fixtures:v1 -t ghcr.io/pulibrary/dpul-collections:fixtures-v1`
1. `export CR_PAT=$(lpass show dpul_collections_fixture_container_github_token --notes)`
1. `echo $CR_PAT | docker login ghcr.io -u pulbot --password-stdin`
1. `docker push ghcr.io/pulibrary/dpul-collections:fixtures-v1`

## Regenerate Cached Files

Delete cached-collection-manifest.json and figgy_manifest_fixtures, then follow the directions above if you want a full from-scratch rebuild.
