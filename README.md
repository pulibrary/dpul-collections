# DpulCollections

## Project Setup for Development and Test environments

### Every time setup

Do these things every time you start new work in this project in dev or test

- `$ lando start` will run the test and dev database and index services
- `mix setup` will install and setup dependencies

### Development environment

- `mix phx.server` will start the phoenix endpoint
- or `iex -S mix phx.server` will start the phoenix endpoint inside IEx

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Running Tests

- `mix test` will run all the test suite
- after tests are run, `./cover` will contain coverage data

## Occasional tasks for Development and Test environments

### Figgy Fixtures

We copy fixtures from Figgy's production database into a Docker container so that we can easily use it for testing indexing. To rebuild that container:

- `brew install lastpass-cli`
- `cd figgy-fixture-container && ./build-and-push.sh`

## Solr configs

We have to keep our solr configuration synchronized with the files that get deployed to the centralized infrastructure in pulibrary/pul_solr. There's a rake task in that repo you can use to copy over all the solr configs from this one. The intended workflow is: make changes here, go to a local checkout of pul_solr, run the task, and create a PR. The task looks like:

```
rake pul_solr:sync FROM_DIR=../dpul-collections CONFIGSET=dpulc-staging
```

## Code contributions

Remember to check formatting before pushing commits.

- `mix format` will format your code
- `mix format --check-formatted` will tell you formatting that must be done.

## Production tasks

### Deployment

1. Connect to VPN
1. `BRANCH=<branch> ./bin/deploy staging`

For more details about an individual deployment, and to view logs, go to the `jobs` section of our [nomad UI](nomad.lib.princeton.edu).

### Restart Indexing Pipeline

The following commands should be run in the shell:

1. Rehydration (full pipeline re-run): `DpulCollections.IndexingPipeline.Figgy.HydrationConsumer.start_over!()`
1. Retransformation (Transform & Index): `DpulCollections.IndexingPipeline.Figgy.TransformationConsumer.start_over!`
1. Reindex (Index Only): `DpulCollections.IndexingPipeline.Figgy.IndexingConsumer.start_over!`

Note: This will use the same cache_version, overwriting the current solr documents and cached records.

### Connecting to Staging Shell or IEX Console

1. Connect to VPN
1. `./bin/console staging [bash/repl]`

### Build & Run Production Docker Image Locally

Build Docker Image: `docker build . -t dpul-collections`

The SECRET_KEY_BASE below is just a filler one for the purpose of testing locally.

Run Docker Image: `docker run -t -p 4000:4000 -e DATABASE_URL='ecto://postgres:@host.docker.internal:5434/database' -e SECRET_KEY_BASE='B8rwzeX3DFLveiJ4cP28lRGc0PWdEr8ZF/hDoPRucw95Nzf2IPnu7lhEB+Yldx6Z' dpul-collections`
