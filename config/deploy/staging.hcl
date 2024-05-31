variable "branch_or_sha" {
  type = string
  default = "main"
}
job "dpulc-staging" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"
  group "web" {
    count = 2
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
      driver = "docker"
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
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        {{- end -}}
        EOF
      }
    }
    task "webserver" {
      driver = "docker"
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
        SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
        {{- end -}}
        EOF
      }
    }
  }
}
