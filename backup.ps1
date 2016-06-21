$account     = 'contoso'
$username    = 'admin'
$password    = '******'
$destination = 'C:\Backups'
$attachments = $false

$today       = Get-Date -format yyyyMMdd
$credential  = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))

# Login
Invoke-WebRequest -Method Post -Uri "https://$account.atlassian.net/login" -SessionVariable session -Body @{username = $username; password = $password} | Out-Null

# Request backup
Invoke-RestMethod -Method Post -Uri "https://$account.atlassian.net/rest/obm/1.0/runbackup" -WebSession $session -ContentType 'application/json' -Body (@{cbAttachments = $attachments} | ConvertTo-Json -Compress) | Out-Null

# Wait for backup to finish
do {
    $status = Invoke-RestMethod -Method Get -Uri "https://$account.atlassian.net/rest/obm/1.0/getprogress" -WebSession $session
    $status.alternativePercentage -match "(\d+)"
    Write-Progress -Activity 'Creating backup' -Status $status.alternativePercentage -PercentComplete $Matches[1]
    Start-Sleep -Seconds 5
} while($status.alternativePercentage -ne 'Estimated progress: 100 %')

# Download
Invoke-WebRequest "https://$account.atlassian.net/webdav/backupmanager/JIRA-backup-$today.zip" -Credential $credential -OutFile (Join-Path -Path $destination -ChildPath "JIRA-backup-$today.zip")
