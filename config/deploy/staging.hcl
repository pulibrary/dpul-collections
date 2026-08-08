variable "branch_or_sha" {
  type = string
  default = "main"
}

variable "solr_configset" {
  type = string
  default = "dpulc-staging"
}

job "dpulc-staging" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"
  node_pool = "staging"
  update {
    auto_revert       = true
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }
  group "web" {
    count = 2
    network {
      port "http" { to = 4000 }
      port "metrics" { to = 4021 }
      port "dist" { to = 4370 }
      # Add the consul DNS loopback, so we can use consul queries.
      dns {
        servers = ["10.88.0.1", "128.112.129.209"]
      }
    }
    service {
      name = "${NOMAD_JOB_NAME}-epmd"
      port = "dist"
      provider = "consul"
      address = "node-${NOMAD_ALLOC_INDEX}-${NOMAD_GROUP_NAME}.${NOMAD_JOB_NAME}-epmd.service.consul"
      address_mode = "auto"
      tags = [
        "node-${NOMAD_ALLOC_INDEX}-${NOMAD_GROUP_NAME}"
      ]
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
        # NOTE: Disabled this because we can take the traffic right now. If that changes, put this back in.
        # "traefik.http.routers.digital-collections-staging-apply-mw.middlewares=captcha-protect@file",
        "traefik.http.routers.digital-collections-staging-apply-mw.priority=10",
        # Health checks lets Traefik keep track of down nodes and lets us monitor uptime.
        "traefik.http.services.dpulc-staging-web.loadbalancer.healthcheck.path=/health",
        "traefik.http.services.dpulc-staging-web.loadbalancer.healthcheck.interval=10s",
        "traefik.http.services.dpulc-staging-web.loadbalancer.healthcheck.timeout=2s"
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
        image = "ghcr.io/pulibrary/dpul-collections:sha-${ var.branch_or_sha }"
        command = "bash"
        args    = ["-c", "([ \"$NOMAD_ALLOC_INDEX\" -eq 0 ] && /app/bin/migrate) || true"]
        force_pull = true
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/solr/staging.json"
        destination = "${NOMAD_TASK_DIR}/solr.json"
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
        image = "ghcr.io/pulibrary/dpul-collections:sha-${ var.branch_or_sha }"
        ports = ["http", "dist", "metrics"]
        force_pull = true
      }
      resources {
        cpu    = 2000
        memory = 1000
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/solr/staging.json"
        destination = "${NOMAD_TASK_DIR}/solr.json"
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
      port "dist" { to = 4370 }

      # Add the consul DNS loopback, so we can use consul queries.
      dns {
        servers = ["10.88.0.1", "128.112.129.209"]
      }
    }
    affinity {
      attribute = "${meta.node_type}"
      value = "worker"
      weight = 100
    }
    service {
      name = "${NOMAD_JOB_NAME}-epmd"
      port = "dist"
      provider = "consul"
      address = "node-${NOMAD_ALLOC_INDEX}-${NOMAD_GROUP_NAME}.${NOMAD_JOB_NAME}-epmd.service.consul"
      address_mode = "auto"
      tags = [
        "node-${NOMAD_ALLOC_INDEX}-${NOMAD_GROUP_NAME}"
      ]
    }
    service {
      name = "dpulc-staging-web"
      tags = ["indexer", "logging"]
      port = "http"
      check {
        type = "http"
        port = "http"
        path = "/health"
        interval = "10s"
        timeout = "1s"
      }
    }
    service {
      name = "dpulc-staging-web"
      tags = ["metrics"]
      port = "metrics"
    }

    task "solr-configset" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      driver = "podman"
      config {
        image   = "docker.io/library/solr:9.9"
        command = "bash"
        args    = ["/local/upconfig.sh"]
      }
      consul {}
      artifact {
        source      = "https://github.com/pulibrary/dpul-collections/archive/${var.branch_or_sha}.tar.gz"
        destination = "local/repo"
      }
      template {
        destination = "local/upconfig.env"
        env         = true
        change_mode = "noop"
        data        = <<-EOT
        ZK_ENSEMBLE={{ $sep := "" }}{{ range $idx, $svcs := service "zookeeper-staging" | byMeta "alloc_index:int" }}{{ range $s := $svcs }}{{ $sep }}{{ $s.Address }}:{{ $s.Port }}{{ $sep = "," }}{{ end }}{{ end }}
        CONFIGSET=${var.solr_configset}
        EOT
      }
      template {
        destination = "local/upconfig.sh"
        perms       = "0755"
        change_mode = "noop"
        data        = <<-EOT
        #!/usr/bin/env bash
        set -euo pipefail

        CONF=$(echo /local/repo/*/solr/conf)
        echo "uploading $CONF as configset '$CONFIGSET' to $ZK_ENSEMBLE"

        # Retry up to 5 times, sometimes Zookeeper wasn't ready.
        for i in $(seq 1 30); do
          if solr zk upconfig -n "$CONFIGSET" -d "$CONF" -z "$ZK_ENSEMBLE"; then
            echo "configset '$CONFIGSET' uploaded"
            exit 0
          fi
          echo "$i failed (retrying in 5s)"
          sleep 5
        done

        echo "couldn't upload '$CONFIGSET'" >&2
        exit 1
        EOT
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
    task "indexer" {
      driver = "podman"
      config {
        image = "ghcr.io/pulibrary/dpul-collections:sha-${ var.branch_or_sha }"
        ports = ["http", "dist", "metrics"]
        force_pull = true
      }
      # Save a bunch of CPU and RAM to run indexing.
      resources {
        cores = 6
        memory = 8000
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/env/staging.tpl"
        destination = "local/env.tpl"
        mode = "file"
      }
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/dpul-collections/${var.branch_or_sha}/config/deploy/solr/staging.json"
        destination = "${NOMAD_TASK_DIR}/solr.json"
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
