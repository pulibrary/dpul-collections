{{- with nomadVar "nomad/jobs/dpulc-production" -}}
APP_ENV = "production"
DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
PHX_HOST = "digital-collections.princeton.edu"
BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
SMTP_HOST = "lib-ponyexpr-prod.princeton.edu"
LIBANSWERS_CLIENT_ID = {{ .LIBANSWERS_CLIENT_ID }}
LIBANSWERS_CLIENT_SECRET = {{ .LIBANSWERS_CLIENT_SECRET }}
LIBANSWERS_QUEUE_ID = {{ .LIBANSWERS_QUEUE_ID }}
ERL_DIST_PORT = 4370
ELIXIR_ERL_OPTIONS = "-start_epmd false -epmd_module Elixir.DynamicSrv.Epmd"
DNS_CLUSTER_QUERY = "{{ env "NOMAD_JOB_NAME" }}-epmd.service.consul"
RELEASE_DISTRIBUTION = "name"
RELEASE_NODE = "node-{{ env "NOMAD_ALLOC_INDEX" }}-{{ env "NOMAD_GROUP_NAME"
}}@{{ env "NOMAD_JOB_NAME" }}-epmd.service.consul"
SERVICE_NAME = "{{ env "NOMAD_JOB_NAME" }}"
CONSUL_SERVICE_ADDRESS = "service.consul"
{{- end -}}
