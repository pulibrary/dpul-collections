#!/bin/bash

# Women Life Freedom Movement: Iran 2022
PROJECT_ID=2961c153-54ab-4c6a-b5cd-aa992f4c349b
# First box in Women Life Freedom Movement
BOX_ID=82624edb-c360-4d8a-b202-f103ee639e8e
EXTRA_RESOURCE_IDS="('f134f41f-63c5-4fdf-b801-0774e3bc3b2d','65044ab4-8860-48f5-a0b1-efe06a1b4340','6c7c204f-be40-429d-8561-24b11ba0e6a5')"

# Export the project
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy (select * from orm_resources WHERE id = '$PROJECT_ID') TO '/tmp/project-export.binary' BINARY\""

# Export the project members recursively
# This will get all the Boxes, Folders, and FileSets
MEMBERS_QUERY=$(cat <<-END
  WITH RECURSIVE deep_members AS (
    select member.*
    FROM orm_resources a,
    jsonb_array_elements(a.metadata->'member_ids') AS b(member)
    JOIN orm_resources member ON (b.member->>'id')::UUID = member.id
    WHERE a.id = '${PROJECT_ID}'
    UNION
    SELECT mem.*
    FROM deep_members f,
    jsonb_array_elements(f.metadata->'member_ids') AS g(member)
    JOIN orm_resources mem ON (g.member->>'id')::UUID = mem.id
    WHERE f.metadata @> '{\"member_ids\": [{}]}'
  )
  select * from deep_members
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($MEMBERS_QUERY) TO '/tmp/project-members-export.binary' BINARY\""

# Just export all the ephemera vocabularies and terms, so we have them.
VOCABULARY_QUERY=$(cat <<-END
  select * from orm_resources WHERE internal_resource = 'EphemeraVocabulary' OR internal_resource = 'EphemeraTerm'
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($VOCABULARY_QUERY) TO '/tmp/project-vocabulary-export.binary' BINARY\""

# Get deletion markers for any Folders deleted from the project's box.
DELETION_MARKERS_QUERY=$(cat <<-END
select * FROM orm_resources WHERE internal_resource='DeletionMarker' AND metadata @> '{\"parent_id\": [{\"id\": \"$BOX_ID\"}]}'
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($DELETION_MARKERS_QUERY) TO '/tmp/project-dm-export.binary' BINARY\""

# Get a few resources we don't want to index in Phase 1-3
IGNORABLE_RESOURCES_QUERY=$(cat <<-END
select * from orm_resources WHERE internal_resource = 'Event' LIMIT 10
END
)
IGNORABLE_RESOURCES_QUERY_2=$(cat <<-END
select * from orm_resources WHERE internal_resource = 'ScannedResource' LIMIT 10
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($IGNORABLE_RESOURCES_QUERY) TO '/tmp/project-ignore-export.binary' BINARY\""
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($IGNORABLE_RESOURCES_QUERY_2) TO '/tmp/project-ignore2-export.binary' BINARY\""

# Export extra resources
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy (select * from orm_resources WHERE id IN $EXTRA_RESOURCE_IDS) TO '/tmp/extras-export.binary' BINARY\""

# Export the extra resource members recursively
EXTRAS_MEMBERS_QUERY=$(cat <<-END
  WITH RECURSIVE deep_members AS (
    select member.*
    FROM orm_resources a,
    jsonb_array_elements(a.metadata->'member_ids') AS b(member)
    JOIN orm_resources member ON (b.member->>'id')::UUID = member.id
    WHERE a.id IN ${EXTRA_RESOURCE_IDS}
    UNION
    SELECT mem.*
    FROM deep_members f,
    jsonb_array_elements(f.metadata->'member_ids') AS g(member)
    JOIN orm_resources mem ON (g.member->>'id')::UUID = mem.id
    WHERE f.metadata @> '{\"member_ids\": [{}]}'
  )
  select * from deep_members
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($EXTRAS_MEMBERS_QUERY) TO '/tmp/extras-members-export.binary' BINARY\""

# Get the DB schema
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD pg_dump -Fc -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -f /tmp/db-schema.sql --schema-only \$FIGGY_DB"

scp deploy@figgy-web-prod1.princeton.edu:/tmp/db-schema.sql fixture-exports/
scp deploy@figgy-web-prod1.princeton.edu:/tmp/*-export.binary fixture-exports/
