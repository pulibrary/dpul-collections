# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://github.com/GoogleContainerTools/distroless - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.16.3-erlang-26.2.5-debian-bullseye-20240513-slim
#
# renovate: datasource=hexpm-bob depName=elixir
ARG ELIXIR_VERSION=1.20.4
# renovate: datasource=github-tags depName=erlang packageName=erlang/otp
ARG OTP_VERSION=29.1
# renovate: datasource=docker depName=debian packageName=debian
ARG DEBIAN_VERSION=trixie-20260918-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="gcr.io/distroless/cc-debian13:nonroot"

FROM ${RUNNER_IMAGE} AS runner

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install JavaScript dependencies
# renovate: datasource=node-version depName=node
ARG NODE_VERSION=24.21.0
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master


# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"
ENV NODE_ENV="production"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# Generate a version.txt file
ARG DEPLOY_BRANCH
ARG DEPLOY_SHA
ARG VERSION_MESSAGE="Ref ${DEPLOY_BRANCH} (at ${DEPLOY_SHA})"
RUN echo ${VERSION_MESSAGE} > priv/static/version.txt

# Compile the release
RUN mix compile

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

RUN cd /app/_build/${MIX_ENV}/rel/dpul_collections && \
    ln -s erts-* erts && \
    ln -s "$(cut -d' ' -f2 releases/start_erl.data)" releases/current && \
    rm releases/COOKIE

COPY --from=runner /usr/lib /runner-usr-lib
RUN libdir="usr/lib/$(uname -m)-linux-gnu" && \
    mkdir -p "/runtime-libs/$libdir" && \
    cd /app/_build/${MIX_ENV}/rel/dpul_collections && \
    find . -type f \( -name "*.so*" -o -path "./erts-*/bin/*" \) -exec ldd {} \; 2>/dev/null > /tmp/ldd.txt ; \
    if grep "not found" /tmp/ldd.txt; then exit 1; fi && \
    awk '/=> \//{print $3}' /tmp/ldd.txt | sort -u | while read -r lib; do \
      [ -e "/runner-usr-lib/${libdir#usr/lib/}/$(basename "$lib")" ] || cp -Lv "$lib" "/runtime-libs/$libdir/" ; \
    done

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM runner

ARG MIX_ENV="prod"
COPY --from=builder /runtime-libs/ /

WORKDIR "/app"

# Only copy the final release from the build stage
COPY --from=builder --chown=nonroot:nonroot /app/_build/${MIX_ENV}/rel/dpul_collections ./

ENV LANG=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    ROOTDIR=/app \
    BINDIR=/app/erts/bin \
    EMU=beam \
    PROGNAME=erl \
    RELEASE_ROOT=/app \
    RELEASE_NAME=dpul_collections \
    RELEASE_MODE=embedded \
    RELEASE_TMP=/tmp \
    RELEASE_SYS_CONFIG=/app/releases/current/sys

ENTRYPOINT ["/app/erts/bin/erlexec", "-noshell", "+fnu", "-s", "elixir", "start_cli", \
            "-config", "/app/releases/current/sys", \
            "-boot_var", "RELEASE_LIB", "/app/lib", \
            "-args_file", "/app/releases/current/vm.args"]

CMD ["-mode", "embedded", "-boot", "/app/releases/current/start", "-extra", "--no-halt"]
