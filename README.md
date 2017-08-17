# Introduction

This script can be used to automate backups of Atlassian Cloud JIRA and 
Confluence instances. It is based on Atlassian Labs' automatic-cloud-backup 
script:

* https://bitbucket.org/atlassianlabs/automatic-cloud-backup

This repository contains several fixes to the original backup.sh script, which 
is not even functional in it current state.

This fork was created because Atlassian Labs had ignored all community pull 
requests and issues for several months.

# Requirements

The script uses _curl_ and _jq_.

# Configuration

You will need to create a configuration file for the script to work. To do this, 
copy backup.sh.vars.example to $HOME/.backup.sh.vars and edit it to match your 
environment.

# Usage

Using the script is straightforward. To backup JIRA:

    ./backup.sh --source jira

To backup Confluence (wiki):

    ./backup.sh --source wiki

To backup JIRA without attachments:

    ./backup.sh --source jira --attachments false

Arguments overview:

* -a, --attachments

     Set if attachments should be in the backup. Values are "true" (default) or "false".

* -s, --source

    Set what backup should be created. Default source is Jira. Set the argument to "wiki" or "confluence" to backup Confluence.

* -t, --timestamp

    Set if we should overwrite the previous backup or append a timestamp (default) to prevent just that.
    The former is useful when an external backup program handles backup rotation.
    Set the argument to "false" if there should be no timestamp in the filename.

# Implementation

The script generates an authorization cookie using your Atlassian credentials if

* a cookie does not exist, or
* a cookie exists but is over 24 hours old

Atlassian Cloud only allows _creation_ of one backup per day, counted separately 
for JIRA and Confluence. However, reuse of the cookie allows running the backup 
script several times in the row; if a new backup could not be created, then the 
previously created backup is fetched.

The authorization cookie is used for three things:

* Triggering the creation of a new backup at the Atlassian Cloud end
* Checking backup creation progress
* Downloading the backup once it's ready

# Contributing

If you find a problem please file an issue, or better yet, a pull request.

# License

The license of the original script is unclear. All contributions by me (Samuli 
Seppänen) are licensed under the 2-Clause BSD License:

* https://opensource.org/licenses/BSD-2-Clause
