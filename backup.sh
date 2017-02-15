#!/bin/bash

CONFIG="$HOME/.backup.sh.vars"

if [[ -r "$CONFIG" ]]; then
    . $CONFIG
else
    echo "Usable to load $CONFIG! Please create one based on backup.sh.vars.example"
    exit 1
fi

# Grabs cookies and generates the backup on the UI. 
TODAY=$(TZ=$TIMEZONE date +%Y%m%d)

#Check if we should overwrite the previous backup or append a timestamp to 
#prevent just that. The former is useful when an external backup program handles 
#backup rotation.
if [[ $TIMESTAMP == "true" ]]; then
    OUTFILE="${LOCATION}/JIRA-backup-${TODAY}.zip"
elif [[ $TIMESTAMP == "false" ]]; then
    OUTFILE="${LOCATION}/JIRA-backup.zip"
else
    echo "ERROR: invalid value for TIMESTAMP: should be either \"true\" or \"false\""
    exit 1
fi

COOKIE_FILE_LOCATION=jiracookie
curl --silent --cookie-jar $COOKIE_FILE_LOCATION -X POST "https://${INSTANCE}/rest/auth/1/session" -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}" -H 'Content-Type: application/json' --output /dev/null
#The $BKPMSG variable will print the error message, you can use it if you're planning on sending an email
BKPMSG=$(curl -s --cookie $COOKIE_FILE_LOCATION --header "X-Atlassian-Token: no-check" -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json"  -X POST https://${INSTANCE}/rest/obm/1.0/runbackup -d '{"cbAttachments":"true" }' )
 
#Checks if the backup procedure has failed
if [ "$(echo "$BKPMSG" | grep -ic backup)" -ne 0 ]; then
rm $COOKIE_FILE_LOCATION
exit
fi

#Checks if the backup exists every 10 seconds, 20 times. If you have a bigger instance with a larger backup file you'll probably want to increase that.
for (( c=1; c<=20; c++ ))
do
PROGRESS_JSON=$(curl -s --cookie $COOKIE_FILE_LOCATION https://${INSTANCE}/rest/obm/1.0/getprogress.json)
FILE_NAME=$(echo "$PROGRESS_JSON" | sed -n 's/.*"fileName"[ ]*:[ ]*"\([^"]*\).*/\1/p')

if [[ $PROGRESS_JSON == *"error"* ]]; then
break
fi

if [ ! -z "$FILE_NAME" ]; then
break
fi
sleep 10
done

#If after 20 attempts it still fails it ends the script.
if [ -z "$FILE_NAME" ];
then
rm $COOKIE_FILE_LOCATION
exit
else

#If it's confirmed that the backup exists the file get's copied to the $LOCATION directory.
if [[ $FILE_NAME == *"ondemandbackupmanager/download"* ]]; then
#Download the new way, starting Nov 2016
wget --load-cookies=$COOKIE_FILE_LOCATION -t 0 --retry-connrefused "https://${INSTANCE}/$FILE_NAME" -O "$OUTFILE" >/dev/null 2>/dev/null
else
#Backward compatible download that will not be supported after Nov 2016
wget --user=$USERNAME --password=$PASSWORD -t 0 --retry-connrefused "https://${INSTANCE}/webdav/backupmanager/JIRA-backup-${TODAY}.zip" -O "$OUTFILE" >/dev/null 2>/dev/null
fi

fi
rm $COOKIE_FILE_LOCATION
