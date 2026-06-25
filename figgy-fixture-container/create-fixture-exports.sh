#!/bin/bash

# Women Life Freedom Movement: Iran 2022
PROJECT_ID=2961c153-54ab-4c6a-b5cd-aa992f4c349b
# First box in Women Life Freedom Movement
BOX_ID=82624edb-c360-4d8a-b202-f103ee639e8e

# Extra Resource IDs, what the object is and why we have it
# f134f41f-63c5-4fdf-b801-0774e3bc3b2d - Jusay Mahamud Oral Narrative, video from the Amazingh collection
# 65044ab4-8860-48f5-a0b1-efe06a1b4340 - Фрагмент з картини "Волошки" item from Ukranian art in times of war, added to test font support
# 6c7c204f-be40-429d-8561-24b11ba0e6a5 - چاند گرہن item from Pakistani film collection, added to test font support
# 32b45be9-257e-444c-bc3e-89535146ae2c - An intimate & gay diary item from LGBTQIA+ ephemera, has a content warning
# 256df489-089d-473a-b9bb-c3585bb639af - Astounding transvestite tales, also has a content warning
# 04b11c52-1508-4adc-8b0c-4cd8f726de0b - SAE box 12
# f09fc91d-7a9b-47b5-afff-ce7db76b4e92 - DK SAE Project
# e8abfa75-253f-428a-b3df-0e83ff2b20f9 - Peace appeal, an item from SAE, no box,
# featurable
# e379b822-27cc-4d0e-bca7-6096ac38f1e6 - عورت مارچ, item from SAE, born digital box, featurable
# 1e5ae074-3a6e-494e-9889-6cd01f7f0621 - India : Madras, item from SAE,
# featurable
# 036b86bf-28b0-4157-8912-6d3d9eeaa5a8 - India : Kerala, item from SAE,
# featurable
# d82efa97-c69b-424c-83c2-c461baae8307 - امن جمهوریت مسادى حقوق : 8 مارچ-عالمى یوم خواتین- تحریك خواتین پنجاب, an item from SAE, featurable
# 6d2be738-626f-4b3d-a17a-655501d2ad9e - Монтян Захистить! Кандидат, який живе поруч з вами, an item from print ephemera form Ukraine (note it's also in Princeton Slavic collections), has a mods file attached
# 118983a5-dd6b-4d7a-bb8c-93fb08248cac - Russian and East European posters project, a collection with no contributor blocks, used to test layout
# 52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a - Manuscripts of the Islamic World collection
# 27fd4d29-1170-47a5-891b-f2743873bcef - المحاسن المجتمعة في فضل فضايل الخلفاء الاربعة a manuscript in the above collection (and also Middle East Manuscripts)
# ee3528e9-88a4-4d2b-adee-f05efede87a7 - شاهنامه. a manuscript in the above collection (and also Middle East Manuscripts), added due to popularity
# 1a8c14ca-060c-434f-b999-6191db4c336c - [شاهنامه]. a manuscript in the above collection (and also Middle East Manuscripts), added due to popularity
# 2cc9b5cf-8d33-4f1b-b53f-fcc658770458 - کتاب شاهنامه. a manuscript in the above collection (and also Middle East Manuscripts), added due to popularity
# c66a266c-38ce-4442-90ec-e3e329e6d602 - Ricky renuncia., an LAE item, used for
# testing search results
# ce55ea72-176b-4468-b486-2859822b065f - Pando. 100 logros. Evo 2006-2009. an LAE item, used for testing search results
# 5f78bc1d-940d-4628-9421-98818e3dea35 - 70th year of Women's Indian Association, an SAE item, used for collection banner cropping tests
# f6e8fd9e-947b-4cd8-9e64-c268cfe6ce04 - Aurat march collection
# 31aafb19-eaca-4d02-9780-2ee76b146663 - It's time to ovry-act - Item in the aurat march collection, used to test related collections/projects

# Note! Update the comment above when adding new IDs here!!!
EXTRA_RESOURCE_IDS="('f134f41f-63c5-4fdf-b801-0774e3bc3b2d','65044ab4-8860-48f5-a0b1-efe06a1b4340','6c7c204f-be40-429d-8561-24b11ba0e6a5','32b45be9-257e-444c-bc3e-89535146ae2c', '256df489-089d-473a-b9bb-c3585bb639af', '04b11c52-1508-4adc-8b0c-4cd8f726de0b', 'f09fc91d-7a9b-47b5-afff-ce7db76b4e92', 'e8abfa75-253f-428a-b3df-0e83ff2b20f9', 'e379b822-27cc-4d0e-bca7-6096ac38f1e6', '1e5ae074-3a6e-494e-9889-6cd01f7f0621', '036b86bf-28b0-4157-8912-6d3d9eeaa5a8', 'd82efa97-c69b-424c-83c2-c461baae8307', '6d2be738-626f-4b3d-a17a-655501d2ad9e',  '118983a5-dd6b-4d7a-bb8c-93fb08248cac', '52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a', '27fd4d29-1170-47a5-891b-f2743873bcef', 'ee3528e9-88a4-4d2b-adee-f05efede87a7', '1a8c14ca-060c-434f-b999-6191db4c336c', '2cc9b5cf-8d33-4f1b-b53f-fcc658770458', 'c66a266c-38ce-4442-90ec-e3e329e6d602', 'ce55ea72-176b-4468-b486-2859822b065f', '5f78bc1d-940d-4628-9421-98818e3dea35', 'f6e8fd9e-947b-4cd8-9e64-c268cfe6ce04')"
EXTRA_RESOURCE_ID_ARRAY=${EXTRA_RESOURCE_IDS/\(/\[}
EXTRA_RESOURCE_ID_ARRAY=${EXTRA_RESOURCE_ID_ARRAY/\)/\]}
# For some projects we don't want every member, just the members of one box, so import it but don't get all its boxes/folders.
# SAE, DK - SAE, and Russian and European Posters
NO_MEMBER_IDS="('f99af4de-fed4-4baa-82b1-6e857b230306', 'f09fc91d-7a9b-47b5-afff-ce7db76b4e92', '118983a5-dd6b-4d7a-bb8c-93fb08248cac')"

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
    WHERE a.id IN ${EXTRA_RESOURCE_IDS} AND a.id NOT IN ${NO_MEMBER_IDS}
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

# Export the extra resource parents
EXTRAS_PARENTS_QUERY=$(cat <<-END
  select a.*
  FROM orm_resources a
  WHERE public.get_ids_array(a.metadata, 'member_ids') && array${EXTRA_RESOURCE_ID_ARRAY}
  AND a.metadata @> '{\"member_ids\": [{}]}'
END
)

ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD psql -d \$FIGGY_DB -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -c \"\\copy ($EXTRAS_PARENTS_QUERY) TO '/tmp/extras-parents-export.binary' BINARY\""

# Get the DB schema
ssh deploy@figgy-web-prod1.princeton.edu "cd /opt/figgy/current && PGPASSWORD=\$FIGGY_DB_RO_PASSWORD pg_dump -Fc -U \$FIGGY_DB_RO_USERNAME -h \$FIGGY_DB_HOST -f /tmp/db-schema.sql --schema-only \$FIGGY_DB"

scp deploy@figgy-web-prod1.princeton.edu:/tmp/db-schema.sql fixture-exports/
scp deploy@figgy-web-prod1.princeton.edu:/tmp/*-export.binary fixture-exports/
