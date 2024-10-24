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
        # volumes = ["/grafana_volume:/var/lib/grafana"]
      }
      resources {
        cpu    = 2000
        memory = 2000
      }

    }
  }

}
