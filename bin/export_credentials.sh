#!/bin/bash

# Lastpass ID of the google credentials json in Lastpass.
# This is in Shared-ITIMS-Passwords\DLS\digital-collections-translation-api-key right now.
LASTPASS_NOTE_ID="4756726955161227459"
# Credentials file name.
OUTPUT_FILE=".translatecredentials.json"
# ---------------------

check_login_status() {
    lpass status 2>&1 | grep -q "Logged in"
    return $?
}

if [ -f "$OUTPUT_FILE" ]; then
  exit 0
fi

# Login to lastpass if we're not logged in.
if ! check_login_status; then
    # Prompt for username - the CLI won't ask for it.
    read -p "Lastpass username: " LP_USERNAME

    # Attempt to log in
    if !(lpass login "$LP_USERNAME";) then
      echo "Failed to login to lpass." >&2
      exit 1
    fi
fi

lpass show --notes "$LASTPASS_NOTE_ID" > "$OUTPUT_FILE"
# End of script
exit 0
