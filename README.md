# DpulCollections

To run the development database type: `lando start`

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Running Tests

`mix spec`

This will run all your tests and store your coverage data in `./cover`.

## Build & Run Production Docker Image Locally

Build Docker Image: `docker build . -t dpul-collections`

The SECRET_KEY_BASE below is just a filler one for the purpose of testing locally.

Run Docker Image: `docker run -t -p 4000:4000 -e DATABASE_URL='ecto://postgres:@host.docker.internal:5434/database' -e SECRET_KEY_BASE='B8rwzeX3DFLveiJ4cP28lRGc0PWdEr8ZF/hDoPRucw95Nzf2IPnu7lhEB+Yldx6Z' dpul-collections`

## Deployment

1. Connect to VPN
1. `BRANCH=<branch> ./bin/deploy staging`

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
