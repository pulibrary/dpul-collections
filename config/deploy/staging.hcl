variable "branch_or_sha" {
  type = string
  default = "main"
}
variable "cache_version" {
  type = string
  default = "1"
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
    count = 1
    network {
      port "http" { to = 4000 }
    }
    service {
      port = "http"
      check {
        type = "http"
        port = "http"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
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
        SOLR_URL = {{ .SOLR_URL }}
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        CACHE_VERSION = ${var.cache_version}
        {{- end -}}
        EOF
      }
    }
    task "webserver" {
      driver = "podman"
      config {
        image = "ghcr.io/pulibrary/dpul-collections:${ var.branch_or_sha }"
        ports = ["http"]
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
        SOLR_URL = {{ .SOLR_URL }}
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        CACHE_VERSION = ${var.cache_version}
        {{- end -}}
        EOF
      }
    }
  }
}
