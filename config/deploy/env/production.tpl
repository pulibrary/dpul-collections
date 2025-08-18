{{- with nomadVar "nomad/jobs/dpulc-production" -}}
APP_ENV = "production"
DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
PHX_HOST = "digital-collections.princeton.edu"
BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
DNS_CLUSTER_QUERY = "dpulc-production-web.service.consul"
HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
{{- end -}}
