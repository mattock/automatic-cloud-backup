#!/bin/bash

CONFIG="$HOME/.backup.sh.vars"

if [ -r "$CONFIG" ]; then
    . $CONFIG
else
    echo "Usable to load $CONFIG! Please create one based on backup.sh.vars.example"
    exit 1
fi

usage() {
    echo "Usage: $0 jira|wiki" 
    echo
    exit 1
}

if [ "$1" = "jira" ]; then
    SUBDIR=""
    DOWNLOAD_URL="https://${INSTANCE}"
elif [ "$1" = "wiki" ]; then
    SUBDIR="/wiki"
    DOWNLOAD_URL="https://${INSTANCE}${SUBDIR}/download"
else
    usage
fi

BASENAME=$1
RUNBACKUP_URL="https://${INSTANCE}${SUBDIR}/rest/obm/1.0/runbackup"
PROGRESS_URL="https://${INSTANCE}${SUBDIR}/rest/obm/1.0/getprogress.json"   

# Grabs cookies and generates the backup on the UI. 
TODAY=$(TZ=$TIMEZONE date +%Y%m%d)

#Check if we should overwrite the previous backup or append a timestamp to 
#prevent just that. The former is useful when an external backup program handles 
#backup rotation.
if [ $TIMESTAMP = "true" ]; then
    OUTFILE="${LOCATION}/$BASENAME-backup-${TODAY}.zip"
elif [ $TIMESTAMP = "false" ]; then
    OUTFILE="${LOCATION}/$BASENAME-backup.zip"
else
    echo "ERROR: invalid value for TIMESTAMP: should be either \"true\" or \"false\""
    exit 1
fi

COOKIE_FILE_LOCATION="$HOME/.backup.sh-cookie"

# Only generate a new cookie if one does not exist, or if it is more than 24 
# hours old. This is to allow reuse of the same cookie until a new backup can be 
# triggered.
find $COOKIE_FILE_LOCATION -mtime -1 2> /dev/null |grep $COOKIE_FILE_LOCATION 2>&1 > /dev/null
if [ $? -ne 0 ]; then
    curl --silent --cookie-jar $COOKIE_FILE_LOCATION -X POST "https://${INSTANCE}/rest/auth/1/session" -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}" -H 'Content-Type: application/json' --output /dev/null
fi

# The $BKPMSG variable will print the error message, you can use it if you're planning on sending an email
BKPMSG=$(curl -s --cookie $COOKIE_FILE_LOCATION --header "X-Atlassian-Token: no-check" -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json"  -X POST $RUNBACKUP_URL -d '{"cbAttachments":"true" }' )
 
# Checks if we were authorized to create a new backup
if [ "$(echo "$BKPMSG" | grep -c Unauthorized)" -ne 0 ]; then
    echo "ERROR: authorization failure"
    exit
fi

#Checks if the backup exists every 10 seconds, 20 times. If you have a bigger instance with a larger backup file you'll probably want to increase that.
for (( c=1; c<=20; c++ )) do
    PROGRESS_JSON=$(curl -s --cookie $COOKIE_FILE_LOCATION $PROGRESS_URL)
    FILE_NAME=$(echo "$PROGRESS_JSON" | sed -n 's/.*"fileName"[ ]*:[ ]*"\([^"]*\).*/\1/p')

    echo $PROGRESS_JSON|grep error > /dev/null && break

    if [ ! -z "$FILE_NAME" ]; then
        break
    fi
    sleep 10
done

# If after 20 attempts it still fails it ends the script.
if [ -z "$FILE_NAME" ]; then
    exit
else
    # Download the new way, starting Nov 2016
    curl -s -L --cookie $COOKIE_FILE_LOCATION "$DOWNLOAD_URL/$FILE_NAME" -o "$OUTFILE"
fi
