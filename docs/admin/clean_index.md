# Create a clean Solr index

To write a second index while the current index continues to receive updates and serve reads, update the `index_cache_collections` variable in the relevant `.hcl` deployment file. for example, if the current value is:

```
default = "cache_version:1,write_collection:dpulc-staging1"
```

The new value might be:
```
default = "cache_version:1,write_collection:dpulc-staging1;cache_version:2,write_collection:dpulc-staging2"
```

Note that each write index must be associated with a cache_version, and the two configurations must be separated by a semicolon. The new cache version must always be higher than the existing cache version.

In development this configuration is formatted as a list of keyword lists in the `config :dpul_collections, DpulCollections.IndexingPipeline` block.

With the new write index specified in configuration, deploy the application (or restart your development processes). A full indexing pipeline will start up for each configured cache_version / write_collection pair. The Indexing code will create the new collection and start writing to it.

You should also add the new collection to the [collections config file](https://github.com/pulibrary/pul_solr/blob/main/config/collections.yml) in pul_solr. This ensures that the collection is reloaded when config sets are deployed, and that collections are backed up.

How to tell when it's time to swap to the new solr index! I think you want 2 things:

1. the last record processed in the new cache version indexing consumer is equal to or later than the last record processed in the old cache version indexing consumer
1. the number of records in the new solr collection is about the same as the number of records in the old solr collection. The index size may be slightly larger if for whatever reason the new collection is getting updates faster than the old one. The index size may be smaller if the old index has records that needed to be deleted for some reason.

When you're ready to use the new index, connect to a iex console on the indexer (see the README under "Connecting to Staging Shell or IEX Console") and run `DpulCollections.Solr.set_alias/1`, passing the new collection name.

When you're ready to delete the old index, remove its configuration from the `index_cache_collections` variable and deploy. Then you can connect to the indexer node and run `DpulCollections.Solr.delete_collection/1` with the old collection name. Note that the cache entries will still be in each database cache.
