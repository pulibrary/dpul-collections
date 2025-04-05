#!/bin/bash
if [ ! -f /tmp/created ]; then
  cd /opt/solr
  server/scripts/cloud-scripts/zkcli.sh -zkhost localhost:9983 -cmd putfile /security.json /opt/solr/security.json

  cd /app/solr/conf
  zip -1 -r solr_config.zip ./*

  # since we have to log in to the UI, add a user that's simpler to type
  curl --user solr:SolrRocks http://localhost:8983/solr/admin/authentication -H 'Content-type:application/json' -d '{"set-user": {"user":"pass"}}'

  # these use solr api v2 which is not stable and changes between solr8 and solr 9
  curl -X POST "http://solr:SolrRocks@localhost:8983/solr/admin/configs?action=UPLOAD&name=dpul-collections" -H "Content-type:application/octet-stream" --data-binary @solr_config.zip
  curl -X POST http://solr:SolrRocks@localhost:8983/api/collections/ -H 'Content-type: application/json' -d '{create: {name: dpulc1, config: dpul-collections, numShards: 1}}'
  curl -X POST http://solr:SolrRocks@localhost:8983/api/c -H 'Content-Type: application/json' -d '{create-alias: {name: dpulc, collections:[dpulc1]}}'
  touch /tmp/configured
fi
