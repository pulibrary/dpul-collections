#!/bin/bash

export SOLR_HOST=${SOLR_HOST:="localhost:8983"}
export ZK_HOST=${ZK_HOST:=$SOLR_HOST}
export SOLR_CONFIG_ROOT=${APP_ROOT:="/app/solr/conf"}

solr zk cp file:/opt/solr/security.json zk:/security.json -z $ZK_HOST

cd $SOLR_CONFIG_ROOT

zip -1 -r solr_config.zip ./*

# since we have to log in to the UI, add a user that's simpler to type
curl --user solr:SolrRocks http://$SOLR_HOST/solr/admin/authentication \
     -H 'Content-type:application/json' \
     -d '{"set-user": {"user":"pass"}}'

curl -X POST "http://solr:SolrRocks@$SOLR_HOST/solr/admin/configs?action=UPLOAD&name=dpul-collections" -H "Content-type:application/octet-stream" --data-binary @solr_config.zip

# Solr 9 API
curl -X POST "http://solr:SolrRocks@$SOLR_HOST/api/collections" \
     -H 'Content-Type: application/json' \
     -d '{
       "name": "dpulc1",
       "config": "dpul-collections",
       "numShards": 1
     }'

curl -X POST "http://solr:SolrRocks@$SOLR_HOST/api/aliases" \
     -H 'Content-Type: application/json' \
     -d '{
       "name": "dpulc",
       "collections": ["dpulc1"]
     }'
