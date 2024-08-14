When Producer spins up, initialize last_queried_marker from the ProcessorMarkers table, or set it to 1900.

```mermaid
sequenceDiagram title Figgy Producer
Participant FiggyDatabase
Participant Producer
Participant Acknowledger
Participant Consumer
Participant Batcher as Batcher (batch size of 2)
Participant HydrationCache

Consumer->>Producer: Demand 3 records
Producer->>FiggyDatabase: Query records since last_queried_marker (1900)
FiggyDatabase->>Producer: Return 3 records
Producer->>Producer: Set last_queried_marker to last updated_at
Producer->>Producer: Add all 3 {record_id, updated_at} to pulled_records
Producer->>Consumer: Deliver record[1,2,3]
Consumer->>Consumer: Process record[1]
Consumer->>Batcher: Deliver record[1]
Consumer->>Consumer: Process record[3]
Consumer->>Batcher: Deliver record[3]
Batcher->>HydrationCache: Writes record[1,3]
Batcher->>Acknowledger: Acknowledge record[1,3]
Acknowledger->>Acknowledger: Do error handling
Acknowledger->>Producer: Acknowledge record[1,3]
Producer->>Producer: Update state: Append record[1,3] to acked_records
Producer->>Producer: Update state: Sort acked_records by updated_at
Producer->>Producer: Run Acknowledging Records algorithm
Consumer->>Consumer: Process record[2]
Consumer->>Batcher: Deliver record[2]
Batcher->>Batcher: 1 minute passes
Batcher->>HydrationCache: Writes record[2]
Batcher->>Acknowledger: Acknowledge record[2]
Acknowledger->>Acknowledger: Do error handling
Acknowledger->>Producer: Acknowledge record[2]
Producer->>Producer: Update state: Append record[2] to acked_records
Producer->>Producer: Update state: Sort acked_records by updated_at
Producer->>Producer: Run Acknowledging Records algorithm
Consumer->>Producer: Demand 3 records
Producer->>FiggyDatabase: Query records since last_queried_marker
```

## Managing Producer State

### Acknowledging Records

When receiving acknowledgement for [1,3]:

Start state: `{last_queried_marker: record[3].updated_at, pulled_records: [1,2,3], acked_records: [1,3]}`

If the first element is the same in pulled_records and acked_records, then remove that element from both. Repeat until there's no match. Then write the timestamp from the last element that got removed from pulled_records.

The processor will block during this acknowledgement, so you don't have to worry about race conditions here.

End State: `{last_queried_marker: record[3].updated_at, pulled_records: [2,3], acked_records: [3]}`

Write `1.updated_at` to `ProcessorMarkers`

When receiving Acknowledgement for [2]:

Start State: `{last_queried_marker: record[3].updated_at, pulled_records: [2,3], acked_records: [2,3]}`

End State: `{last_queried_marker: record[3].updated_at, pulled_records: [], acked_records: []}`

Write `3.updated_at` to `ProcessorMarkers`
