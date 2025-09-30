#!/bin/bash

# Setup host and port variables for local development and CI.
if [ -n "$TEST_POSTGRES_FIGGY_HOST" ]; then
  export PG_FIGGY_HOST=$TEST_POSTGRES_FIGGY_HOST
else
  export PG_FIGGY_HOST=localhost
fi

if [ -n "$TEST_POSTGRES_FIGGY_PORT" ]; then
  export PG_FIGGY_PORT=$TEST_POSTGRES_FIGGY_PORT
else
  export PG_FIGGY_PORT=5435
fi

pg_restore -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -d "postgres" --no-owner --no-privileges --role=postgres fixture-exports/db-schema.sql

psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-members-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-vocabulary-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-dm-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-ignore-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/project-ignore2-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/extras-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/extras-members-export.binary BINARY"
psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM fixture-exports/extras-parents-export.binary BINARY"

# Import synthetic fixtures
for file in fixture-exports/synthetic/*.csv; do
  # Check if it's a file (not a directory)
  if [ -f "$file" ]; then
    psql -h $PG_FIGGY_HOST -p $PG_FIGGY_PORT -U postgres -c "\copy orm_resources FROM $file CSV"
  fi
done
