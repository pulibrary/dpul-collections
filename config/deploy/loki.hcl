job "loki" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
  }
  group "loki" {
    count = 1
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    network {
      port "loki" {
        static = 3100
      }
    }
    service {
      name = "loki"
        port = "loki"
        check {
          name     = "Loki healthcheck"
            port     = "loki"
            type     = "http"
            path     = "/ready"
            interval = "20s"
            timeout  = "5s"
            check_restart {
              limit           = 3
                grace           = "60s"
                ignore_warnings = false
            }
        }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.tls=true",
# the middleware has to be declared somewhere else, we only attach it here
        "traefik.http.routers.loki.middlewares=loki-basicauth@file", 
      ]
    }
# volume "loki" {
    #   type      = "host"
    #   read_only = false
    #   source    = "loki"
    # }
    task "loki" {
      driver = "podman"
      config {
        image = "grafana/loki:3.2.1"
        args = [
          "-config.file",
          "local/loki/local-config.yaml",
        ]
        ports = ["loki"]
      }
      # volume_mount {
      #   volume      = "loki"
      #   destination = "/loki"
      #   read_only   = false
      # }
      template {
        data = <<EOH
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: debug
  grpc_server_max_concurrent_streams: 1000

common:
  instance_addr: 127.0.0.1
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

pattern_ingester:
  enabled: true
  metric_aggregation:
    enabled: true
    loki_address: localhost:3100

ruler:
  alertmanager_url: http://localhost:9093

frontend:
  encoding: protobuf
EOH
        destination = "local/loki/local-config.yaml"
      }
      resources {
        cpu    = 512
        memory = 256
      }
    }
  }
}
