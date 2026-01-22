#!/bin/bash

SOLR_HOST="localhost:8983"
ZK_HOST="localhost:9983"

# zkcli.sh is deprecated, use zk putfile now.
solr zk cp file:/opt/solr/security.json zk:/security.json -z $ZK_HOST

# since we have to log in to the UI, add a user that's simpler to type
curl --user solr:SolrRocks http://$SOLR_HOST/solr/admin/authentication \
     -H 'Content-type:application/json' \
     -d '{"set-user": {"user":"pass"}}'

# Upload config with solr binary.
/opt/solr/bin/solr zk upconfig -n dpul-collections -d /app/solr/conf

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
