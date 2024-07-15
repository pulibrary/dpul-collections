#!/bin/bash

pg_restore -d "$POSTGRES_DB" --no-owner --no-privileges --role=$POSTGRES_USER /tmp/fixture-exports/db-schema.sql

psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-members-export.binary BINARY"
psql -d "$POSTGRES_DB" -U $POSTGRES_USER -c "\copy orm_resources FROM /tmp/fixture-exports/project-vocabulary-export.binary BINARY"
