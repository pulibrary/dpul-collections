#!/bin/bash

pg_restore -d "$POSTGRES_DB" --no-owner --no-privileges --role=$POSTGRES_USER /tmp/fixture-exports/db-schema.sql

psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-members-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-vocabulary-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-dm-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-ignore-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-ignore2-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/extras-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/extras-members-export.binary BINARY"

for file in /tmp/fixture-exports/synthetic/*.csv; do
  # Check if it's a file (not a directory)
  if [ -f "$file" ]; then
    psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM $file CSV"
  fi
done
