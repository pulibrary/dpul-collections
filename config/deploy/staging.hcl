variable "branch_or_sha" {
  type = string
  default = "main"
}
variable "host" {
  type = string
  default = "dpul-collections-staging.lib.princeton.edu"
}
variable "solr_read_collection" {
  type = string
  default = "dpulc-staging"
}
variable "index_cache_collections" {
  type = string
  default = "cache_version:5,write_collection:dpulc-staging5;cache_version:6,write_collection:dpulc-staging6"
}
variable "solr_config_set" {
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
      tags = ["frontend", "logging"]
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
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/dpulc-staging" -}}
        DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
        FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
        SOLR_BASE_URL = {{ .SOLR_BASE_URL }}
        SOLR_READ_COLLECTION = ${ var.solr_read_collection }
        INDEX_CACHE_COLLECTIONS = ${var.index_cache_collections}
        SOLR_CONFIG_SET = ${ var.solr_config_set }
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        PHX_HOST = ${var.host}
        BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
        BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
        DNS_CLUSTER_QUERY = "dpulc-staging-web.service.consul"
        HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
        GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
        METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
        {{- end -}}
        EOF
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

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/dpulc-staging" -}}
        DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
        FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
        SOLR_BASE_URL = {{ .SOLR_BASE_URL }}
        SOLR_READ_COLLECTION = ${ var.solr_read_collection }
        INDEX_CACHE_COLLECTIONS = ${var.index_cache_collections}
        SOLR_CONFIG_SET = ${ var.solr_config_set }
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        PHX_HOST = ${var.host}
        BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
        BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
        DNS_CLUSTER_QUERY = "dpulc-staging-web.service.consul"
        HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
        GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
        METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
        {{- end -}}
        EOF
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
        memory = 5000
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/dpulc-staging" -}}
        DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
        FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
        SOLR_BASE_URL = {{ .SOLR_BASE_URL }}
        SOLR_READ_COLLECTION = ${ var.solr_read_collection }
        INDEX_CACHE_COLLECTIONS = ${var.index_cache_collections}
        SOLR_CONFIG_SET = ${ var.solr_config_set }
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        PHX_HOST = ${var.host}
        INDEXER = true
        BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
        BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
        DNS_CLUSTER_QUERY = "dpulc-staging-web.service.consul"
        HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
        GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
        METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
        {{- end -}}
        EOF
      }
    }
  }
}
