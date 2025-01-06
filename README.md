# DpulCollections

Digital Princeton University Library Collections (aka DPUL Collections) is a discovery application built towards our vision to provide an inspiring environment for global communities to engage with diverse digital collections.

This project is built in Elixir using Phoenix LiveView as a web framework and Broadway for the indexing pipeline.

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

### Solr credentials

Solr cloud doesn't allow use of uploaded config sets without some kind of auth in place. Since we upload config sets to our Solr containers in dev and test, they are configured to use basic auth. To log into the UI for either instance you can use the credentials configured on the box (`solr`:`SolrRocks`) or the convenience account set up by our Lando scripts (`user`:`pass`).

## Solr configs

We have to keep our Solr configuration synchronized with the files that get deployed to the centralized infrastructure in pulibrary/pul_solr. There's a rake task in that repo you can use to copy over all the Solr configs from this one. The intended workflow is: make changes here, go to a local checkout of pul_solr, run the task, and create a PR. The task looks like:

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

### Connecting to Staging Shell or IEX Console

1. Connect to VPN
1. `./bin/console staging [bash/repl]`

By default this will connect you to a web node (Issues #193). To connect to an indexer node use the `JOBTASK` env variable:

`JOBTASK=indexer ./bin/console staging repl`

You will know you're connected to an indexer node if `Broadway.all_running()` returns a populated list.

Another way to connect to a shell or iex console is via the [nomad UI](nomad.lib.princeton.edu). Log in and go to jobs > dpulc-staging > exec. select "indexer" then enter the default command `/bin/bash`. To run the iex console do `./bin/dpul_collections remote`.

### Determine active cache version

Connect to the repl console (see above), then run:

`Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline)`

### Restart Indexing Pipeline

You need to know the cache version (referenced below as `n`) for the pipeline you're restarting -- see above. The following commands should be run in the repl console on the indexer container:

1. Rehydration (full pipeline re-run): `DpulCollections.IndexingPipeline.Figgy.HydrationConsumer.start_over!(n)`
1. Retransformation (Transform & Index): `DpulCollections.IndexingPipeline.Figgy.TransformationConsumer.start_over!(n)`
1. Reindex (Index Only): `DpulCollections.IndexingPipeline.Figgy.IndexingConsumer.start_over!(n)`

Note: This will use the same cache_version, overwriting the current Solr documents and cached records.

### Create a clean Solr index

See instructions for creating new clean solr index in [/docs/admin/clean_index.md](/docs/admin/clean_index.md)

### Explore logs

To view staging logs go to https://grafana-nomad.lib.princeton.edu and log in with github. Navigate to the explore tab.

### Build & Run Production Docker Image Locally

Build Docker Image: `docker build . -t dpul-collections`

The SECRET_KEY_BASE below is just a filler one for the purpose of testing locally.

Run Docker Image: `docker run -t -p 4000:4000 -e DATABASE_URL='ecto://postgres:@host.docker.internal:5434/database' -e SECRET_KEY_BASE='B8rwzeX3DFLveiJ4cP28lRGc0PWdEr8ZF/hDoPRucw95Nzf2IPnu7lhEB+Yldx6Z' dpul-collections`
