job "grafana" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"

  group "grafana" {
    count = 1

    network {
      port "grafana" {
        to = 3000
      }
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "grafana"
      check {
        type = "http"
        port = "grafana"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
    }

    volume "grafana" {
      type = "host"
      read_only = false
      source = "grafana"
    }

    task "grafana" {
      driver = "podman"

      env {
        GF_LOG_LEVEL          = "ERROR"
        GF_LOG_MODE           = "console"
        GF_PATHS_DATA         = "/var/lib/grafana"
      }
      user = "root"

      config {
        image = "docker.io/grafana/grafana:11.3.0"
        ports = ["grafana"]
      }
      volume_mount {
        volume = "grafana"
        destination = "/var/lib/grafana"
        read_only = false
      }
      resources {
        cpu    = 2000
        memory = 2000
      }

    }
  }

}
