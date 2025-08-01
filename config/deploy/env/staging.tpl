{{- with nomadVar "nomad/jobs/dpulc-staging" -}}
DATABASE_URL = ecto://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}/{{ .DB_NAME }}
FIGGY_DATABASE_URL = {{ .FIGGY_DATABASE_URL }}
SOLR_BASE_URL = {{ .SOLR_BASE_URL }}
SOLR_READ_COLLECTION = "dpulc-staging"
INDEX_CACHE_COLLECTIONS = "cache_version:5,write_collection:dpulc-staging5"
SOLR_CONFIG_SET = "dpulc-staging"
SECRET_KEY_BASE = {{ .SECRET_KEY_BASE }}
PHX_HOST = "dpul-collections-staging.lib.princeton.edu"
BASIC_AUTH_USERNAME = {{ .BASIC_AUTH_USERNAME }}
BASIC_AUTH_PASSWORD = {{ .BASIC_AUTH_PASSWORD }}
DNS_CLUSTER_QUERY = "dpulc-staging-web.service.consul"
HONEYBADGER_API_KEY = {{ .HONEYBADGER_API_KEY }}
GRAFANA_SERVICE_TOKEN = {{ .GRAFANA_SERVICE_TOKEN }}
METRICS_AUTH_TOKEN = {{ .METRICS_AUTH_TOKEN }}
{{- end -}}
{{- with index (service "signoz-collector-otel-agent~_agent") 0 -}}
OTLP_ENDPOINT = "{{ .Address }}:{{ .Port }}"
{{- end -}}
