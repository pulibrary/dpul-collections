# Create a clean Solr index

## Step 1: start the new index

To write a second index while the current index continues to receive updates and serve reads, add another write index to the solr configuration in the relevant `config/deploy/solr/env.json` file.

Note that each write index must be associated with its own cache_version, and the new cache version must always be higher than the existing cache version.

In development this configuration is entered directly into `config/dev.exs`.

With the new write index specified in configuration, deploy the application (or restart your development processes). A full indexing pipeline will start up for each configured write index. The Indexing code will create the new collection and start writing to it.

## Step 2: swap in the new index

How to tell when it's time to swap to the new solr index! I think you want 2 things:

1. the last record processed in the new cache version indexing consumer is equal to or later than the last record processed in the old cache version indexing consumer. To check this look for `DpulCollections.IndexingPipeline.Coherence.index_parity?()` to return `true`.
1. the number of records in the new solr collection is about the same as the number of records in the old solr collection. The index size may be slightly larger if for whatever reason the new collection is getting updates faster than the old one. The index size may be smaller if the old index has records that needed to be deleted for some reason. To see the compartive size of the two indexes do `DpulCollections.IndexingPipeline.Coherence.document_count_report()`

When you're ready to use the new index, connect to a iex console on the indexer (see the README under "Connecting to Staging Shell or IEX Console") and run `DpulCollections.Solr.Management.set_alias/2`, passing the new write index and the alias name, which should be the collection name used for the read collection. For example:

```
read_index = DpulCollections.Solr.Index.read_index()
[old_write_index, new_write_index] = DpulCollections.Solr.Index.write_indexes()
DpulCollections.Solr.Management.set_alias(new_write_index, read_index.collection)
```

## Step 3: stop and clean up the old index

When you're ready to delete the old index, remove its configuration from the relevant config file and deploy. Then you can connect to the indexer node and run `DpulCollections.Solr.Management.delete_collection/1`, passing the old write index. To delete all the database entries for that cache version use `DpulCollections.IndexingPipeline.delete_cache_version/1`.
