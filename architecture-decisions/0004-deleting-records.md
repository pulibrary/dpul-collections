# 4. Deleting Records

Date: 2025-02-18

## Status

Accepted

## Context

When resources are deleted in Figgy, a DeletionMarker resource is created at the
same time. The DeletionMarker stores the deleted resource's identifier,
resource type, and a serialized copy of the  metadata (in the `deleted_object`
field). We need a method for processing DeletionMarkers in DPUL-C to remove the
corresponding record from the Solr index.

## Decision

#### Hydration Consumer

1. We will process DeletionMarkers that reference a deleted resource with a
resource type that we currently index into DPUL-C. In addition, we will check
if a hydration cache entry exists for the deleted resource and discard the 
DeletionMarker if not.
1. A special CacheMarker is created from the DeletionMarker that uses the
   deleted resource's id as the id and the updated_at value from the
   DeletionMarker as the timestamp.
1. Special hydration cache entry attributes are generated. The hydration cache
   entry created from these attributes will replace the hydration cache entry of
   the deleted resource.
    -  Existing metadata is replaced with a simple deleted => true kv pair
    -  The entry id is set to the deleted resource's id
    -  The entry internal_resource type is set to that of the deleted resource

#### Transformation Consumer

1. A special solr document is generated from the deleted object hydration cache
entry with the following structure.
  ```
    %{ id: "id", deleted: true }
  ```

####  Indexing Consumer

1. Messages with the `deleted: true` field are handled sperately and assigned to
   the `delete` batcher.
1. The delete batcher sends the deleted record ids to a the Solr.delete_batch
   function which iterates over them, deletes each record, and then commits the
   batch of deletes. The additional batcher doesn't create a potential race
   condition because there is only one entry for the resource earlier in the
   pipeline.

## Consequences

- DeletionMarkers will stay in the Figgy database unless the resource is
restored. This means that DPUL-C will have to triage an ever increasing number
over time.

- Deleted resource hydration and transformation cache entries will stay in the 
cache after the resource is remove from Solr until the next full reindex.
