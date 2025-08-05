variable "branch_or_sha" {
  type = string
  default = "main"
}
variable "branch" {
  type = string
  default = "main"
}

job "dpulc-staging" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"
  node_pool = "staging"
  update {
    auto_revert       = true
  }
  group "web" {
    count = 2
    network {
      port "http" { to = 4000 }
      port "metrics" { to = 4021 }
      port "epmd" { static = 6789 }
      # Add the consul DNS loopback, so we can use consul queries.
      dns {
        servers = ["10.88.0.1", "128.112.129.209"]
      }
    }
    service {
      port = "http"
      name = "dpulc-staging-web"
      tags = [
        "frontend",
        "logging",
        # Enable traefik for bot protection.
        "traefik.enable=true",
        # Router 1: digital-collections-staging-skip-all-mw
        # Skips middleware if it's an ajax request.
        "traefik.http.routers.digital-collections-staging-skip-all-mw.rule=Header(`X-Forwarded-Host`, `dpul-collections-staging.lib.princeton.edu`) && Header(`Sec-Fetch-Dest`, `empty`)",
        "traefik.http.routers.digital-collections-staging-skip-all-mw.priority=11",
        # Router 2: digital-collections-staging-apply-mw
        # Applies captcha-protect middleware if it's not ajax.
        "traefik.http.routers.digital-collections-staging-apply-mw.rule=Header(`X-Forwarded-Host`, `dpul-collections-staging.lib.princeton.edu`)",
        "traefik.http.routers.digital-collections-staging-apply-mw.middlewares=captcha-protect@file",
        "traefik.http.routers.digital-collections-staging-apply-mw.priority=10"
      ]
      check {
        type = "http"
        port = "http"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
    }
    service {
      name = "dpulc-staging-web"
      tags = ["metrics"]
      port = "metrics"
    }
    affinity {
      attribute = "${meta.node_type}"
      value = "default"
      weight = 100
    }
    task "release-migrate" {
      # The dbmigrate task will run BEFORE the puma task in this group.
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      driver = "podman"
      config {
        image = "ghcr.io/pulibrary/dpul-collections:${ var.branch_or_sha }"
        command = "bash"
        args    = ["-c", "/app/bin/migrate"]
        force_pull = true
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      template {
        source = "local/env.tpl"
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
      }
    }
    task "webserver" {
      driver = "podman"
      config {
        image = "ghcr.io/pulibrary/dpul-collections:${ var.branch_or_sha }"
        ports = ["http", "epmd", "metrics"]
        force_pull = true
      }
      resources {
        cpu    = 2000
        memory = 1000
      }
      env {
        RELEASE_IP = "${NOMAD_IP_http}"
        ERL_DIST_PORT = 6789
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      template {
        source = "local/env.tpl"
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
      }
    }
  }
  group "indexer" {
    count = 1
    network {
      port "http" { to = 4000 }
      port "metrics" { to = 4021 }
      port "epmd" { static = 6789 }
    }
    affinity {
      attribute = "${meta.node_type}"
      value = "worker"
      weight = 100
    }
    service {
      name = "dpulc-staging-web"
      tags = ["indexer", "logging"]
      port = "http"
      check {
        type = "http"
        port = "http"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
    }
    service {
      name = "dpulc-staging-web"
      tags = ["metrics"]
      port = "metrics"
    }
    task "indexer" {
      driver = "podman"
      config {
        image = "ghcr.io/pulibrary/dpul-collections:${ var.branch_or_sha }"
        ports = ["http", "epmd", "metrics"]
        force_pull = true
      }
      env {
        RELEASE_IP = "${NOMAD_IP_http}"
        ERL_DIST_PORT = 6789
      }
      # Save a bunch of CPU and RAM to run indexing.
      resources {
        cores = 6
        memory = 8000
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      template {
        source = "local/env.tpl"
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/indexer_env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
          INDEXER = true
        EOF
      }
    }
  }
}
