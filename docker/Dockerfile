FROM quay.io/pulibrary/ci-solr:8.4-2.0.0
USER root
RUN apt-get update && apt-get install ruby -y
USER solr
ADD solr/config /opt/solr/solrconfig
RUN start-local-solr && /opt/solr/bin/solr create -c core -d /opt/solr/solrconfig
