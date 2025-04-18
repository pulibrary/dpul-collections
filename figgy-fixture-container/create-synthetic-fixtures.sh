#!/bin/bash

# IDS
# Figgy resouces like EphemeraFolders where we do want to export members like FileSets directly

# IDS_NO_MEMBERS
# Figgy resources like EphemeraBoxes where we don't want to export members directly
#
# Example:
# IDS="('43ae3839-287e-4168-b85d-a9350d279402')" IDS_NO_MEMBERS="('7b87fdfa-a760-49b9-85e9-093f2519f2fc')" ./create-synthetic-fixtures.sh

# Clear old csv exports from server
ssh deploy@figgy-web-prod1.princeton.edu "rm /tmp/synth-*-export.csv"

if [ -n "$IDS_NO_MEMBERS" ]; then
# Export resources with no members
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy (select * from orm_resources WHERE id IN $IDS_NO_MEMBERS) TO '/tmp/synth-1-export.csv' CSV\""
fi

if [ -n "$IDS" ]; then
# Export resources with members
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy (select * from orm_resources WHERE id IN $IDS) TO '/tmp/synth-2-export.csv' CSV\""

# Export the resource members recursively
SYNTHETIC_MEMBERS_QUERY=$(cat <<-END
  WITH RECURSIVE deep_members AS (
    select member.*
    FROM orm_resources a,
    jsonb_array_elements(a.metadata->'member_ids') AS b(member)
    JOIN orm_resources member ON (b.member->>'id')::UUID = member.id
    WHERE a.id IN ${IDS}
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

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($SYNTHETIC_MEMBERS_QUERY) TO '/tmp/synth-3-export.csv' CSV\""
fi

# Get export files
scp deploy@figgy-web-prod1.princeton.edu:/tmp/*-export.csv fixture-exports/synthetic/

# Concat csv exports
cat fixture-exports/synthetic/synth-*-export.csv > fixture-exports/synthetic/synthetic-fixtures.csv

# Remove local working files
rm fixture-exports/synthetic/synth-*-export.csv
