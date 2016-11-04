#!/bin/bash
USERNAME=youruser
PASSWORD=yourpassword
INSTANCE=example.atlassian.net
LOCATION=/where/to/store/the/file

# Set this to your Atlassian instance's timezone.
# See this for a list of possible values:
# https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
TIMEZONE=America/Los_Angeles
 
# Grabs cookies and generates the backup on the UI. 
TODAY=`TZ=$TIMEZONE date +%Y%m%d`
COOKIE_FILE_LOCATION=jiracookie
curl --silent --cookie-jar $COOKIE_FILE_LOCATION -X POST "https://${INSTANCE}/rest/auth/1/session" -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}" -H 'Content-Type: application/json' --output /dev/null
BKPMSG=`curl -s --cookie $COOKIE_FILE_LOCATION --header "X-Atlassian-Token: no-check" -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json"  -X POST https://${INSTANCE}/rest/obm/1.0/runbackup -d '{"cbAttachments":"true" }' `
 
#Checks if the backup procedure has failed
if [ `echo $BKPMSG | grep -i backup | wc -l` -ne 0 ]; then
#The $BKPMSG variable will print the error message, you can use it if you're planning on sending an email
rm $COOKIE_FILE_LOCATION
exit
fi

#Checks if the backup exists every 10 seconds, 20 times. If you have a bigger instance with a larger backup file you'll probably want to increase that.
for (( c=1; c<=20; c++ ))
do
PROGRESS_JSON=`curl -s --cookie $COOKIE_FILE_LOCATION https://${INSTANCE}/rest/obm/1.0/getprogress.json`
FILE_NAME=`echo $PROGRESS_JSON | sed -n 's/.*"fileName"[ ]*:[ ]*"\([^"]*\).*/\1/p'`

if [[ $PROGRESS_JSON == *"error"* ]]; then
break
fi

if [ ! -z $FILE_NAME ]; then
break
fi
sleep 10
done

#If after 20 attempts it still fails it ends the script.
if [ -z $FILE_NAME ];
then
rm $COOKIE_FILE_LOCATION
exit
else

#If it's confirmed that the backup exists the file get's copied to the $LOCATION directory.
if [[ $FILE_NAME == *"ondemandbackupmanager/download"* ]]; then
#Download the new way, starting Nov 2016
wget --load-cookies=$COOKIE_FILE_LOCATION -t 0 --retry-connrefused https://${INSTANCE}/$FILE_NAME -O "$LOCATION/JIRA-backup-${TODAY}.zip" >/dev/null 2>/dev/null
else
#Backward compatible download that will not be supported after Nov 2016
wget --user=$USERNAME --password=$PASSWORD -t 0 --retry-connrefused https://${INSTANCE}/webdav/backupmanager/JIRA-backup-${TODAY}.zip -P "$LOCATION" >/dev/null 2>/dev/null
fi

fi
rm $COOKIE_FILE_LOCATION
