# 2. Indexing Architecture

Date: 2024-07-09

## Status

Accepted

## Context

DPUL-Collections must have a resilient indexing pipeline that can quickly harvest, transform, and index records. We foresee needing to process millions of records, regularly change weighting algorithms, and accept records from external institutions which may not be stable in the long term.

There must be a verifiable method of ensuring that 100% of Figgy's relevant records are indexed into DPUL-Collections, to prevent us from constantly scrambling and diagnosing indexing issues as we do now with our spotlight-powered DPUL.

We will initially pull data from Figgy, so the performance requirements in this document are based on the size of Figgy's database.

Often times systems like this use event streaming platforms such as Kafka, but we'd like to prevent adding new technology to our stack. We think we can use Postgres tables as a compact event log.

## Decision

Our indexing pipeline will consist of three steps - Hydration, Transformation, and Indexing. Collectively we'll call these the Processors. 

Each step has a performance requirement - the lower bound is the point at which we stop optimizing in the case of running that full process, the upper bound is the maximum we'll allow it to take before re-architecting.

For newly added records (not a full pipeline run of all records), we expect to see changes within five minutes of persistence in Figgy, as our stakeholders often do patron requests by "Completing" a record in Figgy and then sending a resource to a patron. They shouldn't have to wait more than 5 minutes to do that.

```mermaid
flowchart LR
    A[Figgy Postgres] -->|Hydrate| B[Hydration Log]
    B -->|Transform| C[Transformation Log]
    C -->|Index| D[Solr Index]
```

### Hydration

The Hydrator will query Figgy's `orm_resources` table for newly updated records and copy them into a local postgres cache (the Hydration Log). This pattern will allow us to do the transformation and indexing steps no matter the uptime or performance characteristics of our source repository.

The Hydration Log has the following structure:

| id   | data  | log_order | log_version | record_id |
|------|-------|-----------|-------------|-----------|
| INT  | BLOB  | INT       | INT         | VARCHAR   |

We'll pull records as well as DeletionMarkers so we'll know and record when records have been deleted from Figgy.

If retries have been enqueued, the Hydrator will pull from the retry queue instad of from Figgy. For each resource ID in the retry queue, the Hydrator will duplicate the last row found for that resource in the Hydration Log, updating its log order to be the next number in the sequence.

#### Performance Requirements for Full Hydration

1 Hour - 2 Days

##### Performance Reasoning

The faster we can do a full re-harvest, the faster we can pull in broad metadata changes from upstream (such as new Figgy or Bibdata data.) We want these kinds of tickets to have at most two days of delay.

### Transformation

The Transformer will query the Hydration Log to fetch the records cached by the Hydration step, convert them to a Solr document, and store that solr document in a local postgres cache (the Transformation Log) with the following structure:

| id   | data  | log_order | log_version | record_id | error   |
|------|-------|-----------|-------------|-----------|---------|
| INT  | BLOB  | INT       | INT         | VARCHAR   | TEXT    | 

#### Performance Requirements for Full Transformation

30 minutes - 2 hours

##### Performance Reasoning

We will need to do a re-transformation when we add new fields to the index, which we expect to do often. The faster we can do that, the more of those tickets we can do. With a two hour transformation stage we can do more than one such transformation per day, significantly improving our productivity.

### Indexing

The Indexer will query the Transformation Log to fetch the records cached by the Transformation step and index them into Solr as a batch.

#### Performance Requirements for Full Indexing

10 minutes - 1 hour

##### Performance Reasoning

We expect reindexing to need to happen often - either because of changing weights in Solr, migrating Solr machines, or testing new configurations. By tightening up this time as much as possible we can try many different weights in a day, supporting our vision of being able to create a joyful discovery experience. We believe this performance estimate is reasonable given that there won't be any transformation necessary - it will go as fast as Solr can accept documents.

## Sequence Diagram

```mermaid
---
title: A full Indexing Pipeline workflow
---

sequenceDiagram
Participant LogLocationTable
Participant FiggyDB
Participant RetryQueue
Participant HydratorV1 as Hydrator(log_version: 1)
Participant HydrationLog
Participant TransformerV1 as Transformer(log_version: 1)
Participant TransformationLog
Participant IndexerV1 as Indexer(log_version: 1, solr_collection: dpul)
Participant SolrIndex

HydratorV1->>LogLocationTable: Set(type: hydrator, log_location: pre_figgy_timestamp, log_version: 1)
loop Populate the Log in Batches
HydratorV1->>RetryQueue: Get resource IDs from queue
HydratorV1->>HydratorV1: Duplicate retry resource rows into log
HydratorV1->>LogLocationTable: Get last log_location
HydratorV1->>FiggyDB: Get X (e.g. 500) records with update_at later than log_location
HydratorV1->>HydrationLog: Store the records with log version 1
HydratorV1->>LogLocationTable: Set(log_location: latest_updated_at_from_batch)
HydratorV1->>HydratorV1: Sleep for poll interval if recordset is empty
end

TransformerV1->>LogLocationTable: Set(type: transformer, log_location: 0, log_version: 1)
loop Populate the TransformationLog in Batches
TransformerV1->>LogLocationTable: Get last log_location
TransformerV1->>HydrationLog: Get X (e.g. 500) records with log_order higher than log_location
TransformerV1->>TransformationLog: Store the transformed records with log version 1
TransformerV1->>LogLocationTable: Set(log_location: highest_log_order from that batch)
TransformerV1->>TransformerV1: Sleep for poll interval if recordset is empty
end

IndexerV1->>LogLocationTable: Set(type: indexer, log_location: 0, log_version: 1)
loop Populate the SolrIndex in Batches
IndexerV1->>LogLocationTable: Get last log_location
IndexerV1->>TransformationLog: Get X (e.g. 500) records with log_order higher than log_location
IndexerV1->>SolrIndex: Store the documents
IndexerV1->>LogLocationTable: Set(log_location: highest_log_order from that batch)
IndexerV1->>IndexerV1: Sleep for poll interval if recordset is empty
end
```

## Commonalities between Processors

Each Processor will keep track of the last object they acted on in a LogLocationTable with the following structure:


| id   | log_location | log_version | type    |
|------|--------------|-------------|---------|
| INT  | varchar      | INT         | VARCHAR |

- For Hydrator, `log_location` is an `updated_at` value from the Figgy database.
- For Transformer, `log_location` is a `log_order` value from the HydrationLog
- For Indexer, `log_location` is a `log_order` value from the TransformationLog

The value of `log_version` will be the same for each Processor within a given pipeline. It will be configured manually before a full pipeline run. It will be used to read the correct rows out of each log.

## Concurrent Logic

To support concurrency in these processes:

- We will pull batches from an event log serially and only parallelize within a batch
- When we pull from an event log we will ensure we only pull the most recent entry for each record id

## Event Log Cleanup

We will periodically delete rows from each event log as follows:

- Where multiple rows have the same record_id, the older ones will be deleted
- We believe we can always do this without race conditions

## Resilience and Error Handling 
If postgres or Solr fails, we should let the Processors crash and restart indefinitely. When the service comes back up, they will resume their expected operation.

When a Transformation error occurs:
0. The Transformer does its best to create a Solr record, with incomplete data. 
1. It gets logged by writing the error message in the `error` field and sending the notification to Honeybadger.
2. DLS can review errors via scripts and Honeybadger weekly review.
3. DLS fixes error(s).
4. DLS adds the record ID to the retry queue.

## Consequences

We need to find a way to validate that we're indexing 100% of the documents that we pull from Figgy.

The event logs will contain every deleted figgy resource.

Keeping track of three different tables may be complicated. However, we expect to be able to scale this architecture out to allow for multiple harvest sources and transformation steps in the future.
