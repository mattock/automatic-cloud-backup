#!/bin/bash

CONFIG="$HOME/.backup.sh.vars"
ATTACHMENTS="true"
FILEPREFIX="JIRA"

if [ -r "$CONFIG" ]; then
    . $CONFIG
    DOWNLOAD_URL="https://${INSTANCE}/plugins/servlet/export/download"
    INSTANCE_PATH=$INSTANCE
else
    echo "Usable to load $CONFIG! Please create one based on backup.sh.vars.example"
    exit 1
fi

while [[ $# -gt 1 ]]
do
    key="$1"

    case $key in
        -s|--source)
            if [[  $2 == "wiki" ]] || [[ $2 == "confluence" ]]; then
                INSTANCE_PATH=$INSTANCE/wiki
                DOWNLOAD_URL="https://${INSTANCE_PATH}/download"
                FILEPREFIX="CONFLUENCE"
            fi
            shift # past argument
            ;;
        -a|--attachments)
            if [[  $2 == "false" ]]; then
                ATTACHMENTS="false"
            fi
            shift # past argument
            ;;
        -t|--timestamp)
            if [[  $2 == "false" ]]; then
                TIMESTAMP=false
            fi
            shift # past argument
            ;;

    esac
    shift # past argument or value
done

BASENAME=$1
LASTTASK_URL="https://${INSTANCE_PATH}/rest/backup/1/export/lastTaskId"

if [ $FILEPREFIX = "JIRA" ]; then
    RUNBACKUP_URL="https://${INSTANCE_PATH}/rest/backup/1/export/runbackup"
    PROGRESS_URL="https://${INSTANCE_PATH}/rest/internal/2/task/progress/"
else
    RUNBACKUP_URL="https://${INSTANCE_PATH}/rest/obm/1.0/runbackup"
    PROGRESS_URL="https://${INSTANCE_PATH}/rest/obm/1.0/getprogress.json"
fi

# Grabs cookies and generates the backup on the UI. 
TODAY=$(TZ=$TIMEZONE date +%Y%m%d)

#Check if we should overwrite the previous backup or append a timestamp to 
#prevent just that. The former is useful when an external backup program handles 
#backup rotation.
if [ $TIMESTAMP = "true" ]; then
    OUTFILE="${LOCATION}/$FILEPREFIX-backup-${TODAY}.zip"
elif [ $TIMESTAMP = "false" ]; then
    OUTFILE="${LOCATION}/$FILEPREFIX-backup.zip"
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
    chmod 600 $COOKIE_FILE_LOCATION
fi

# The $BKPMSG variable will print the error message, you can use it if you're planning on sending an email
BKPMSG=$(curl -s --cookie $COOKIE_FILE_LOCATION $RUNBACKUP_URL \
    -X POST \
    -H 'DNT: 1' \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/javascript, */*; q=0.01' \
    -H 'X-Requested-With: XMLHttpRequest' \
    --data-binary "{\"cbAttachments\":\"${ATTACHMENTS}\", \"exportToCloud\":\"true\" }" )

# Checks if we were authorized to create a new backup
if [ $FILEPREFIX = "JIRA" ]; then
    STATUS_CODE=$(echo "$BKPMSG" | jq '."status-code"' -r)

    if [ "$STATUS_CODE" == "401" ]; then
        echo "ERROR: authorization failure"
        exit
    fi
else
    if [ "$(echo "$BKPMSG" | grep -c Unauthorized)" -ne 0 ]  || [ "$(echo "$BKPMSG" | grep -ic "<status-code>401</status-code>")" -ne 0 ]; then
        echo "ERROR: authorization failure"
        exit
    fi
fi

# Checks if the backup exists every $SLEEP_SECONDS seconds, $PROGRESS_CHECKS times.
for (( c=1; c<=$PROGRESS_CHECKS; c++ )) do

    if [ $FILEPREFIX = "JIRA" ]; then
        LASTTASKID=$(curl -s --cookie $COOKIE_FILE_LOCATION $LASTTASK_URL)
        PROGRESS_JSON=$(curl -s --cookie $COOKIE_FILE_LOCATION $PROGRESS_URL$LASTTASKID)

        STATUS=$(echo "$PROGRESS_JSON" | jq '.status' -r)

        if [ "$STATUS" == "Success" ]; then
            FILE_NAME=$(echo $PROGRESS_JSON | jq '.result' -r | jq '"\(.mediaFileId)/\(.fileName)"' -r)
            break
        fi
    else
        PROGRESS_JSON=$(curl -s --cookie $COOKIE_FILE_LOCATION $PROGRESS_URL)
        FILE_NAME=$(echo "$PROGRESS_JSON" | sed -n 's/.*"fileName"[ ]*:[ ]*"\([^"]*\).*/\1/p')
        echo $PROGRESS_JSON|grep error > /dev/null && break

        if [ ! -z "$FILE_NAME" ]; then
            break
        fi
    fi
    sleep $SLEEP_SECONDS
done

# If after $PROGRESS_CHECKS attempts it still fails it ends the script.
if [ -z "$FILE_NAME" ]; then
    exit
else
    # Download the new way, starting Nov 2016
    curl -s -S -L --cookie $COOKIE_FILE_LOCATION "$DOWNLOAD_URL/$FILE_NAME" -o "$OUTFILE"
fi
