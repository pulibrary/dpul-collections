FROM solr:8.4
USER root
RUN apt-get update && apt-get install ruby -y
USER solr
ADD solr/config /opt/solr/solrconfig
RUN start-local-solr && /opt/solr/bin/solr create -c core -d /opt/solr/solrconfig
ADD figgy_manifest_fixtures /opt/solr/figgy_manifest_fixtures
RUN start-local-solr && /opt/solr/bin/post -c core /opt/solr/figgy_manifest_fixtures
