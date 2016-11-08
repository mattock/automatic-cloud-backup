$account     = 'contoso'
$username    = 'admin'
$password    = '******'
$destination = 'C:\Backups'
$attachments = $false

$hostname    = "$account.atlassian.net"
$today       = Get-Date -format yyyyMMdd
$credential  = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))

if ($PSVersionTable.PSVersion.Major -lt 4) {
    throw "Script requires at least PowerShell version 4. Get it here: https://www.microsoft.com/en-us/download/details.aspx?id=40855"
}

# Login
Invoke-WebRequest -Method Post -Uri "https://$hostname/login" -SessionVariable session -Body @{username = $username; password = $password} | Out-Null

# Request backup
Invoke-RestMethod -Method Post -Uri "https://$hostname/rest/obm/1.0/runbackup" -WebSession $session -ContentType 'application/json' -Body (@{cbAttachments = $attachments} | ConvertTo-Json -Compress) | Out-Null

# Wait for backup to finish
do {
    $status = Invoke-RestMethod -Method Get -Headers @{"Accept"="application/json"} -Uri "https://$hostname/rest/obm/1.0/getprogress" -WebSession $session
    if ($status.alternativePercentage -match "(\d+)") {
        $percentage = $Matches[1]
        if ([int]$percentage -gt 100) {
            $percentage = "100"
        }
        Write-Progress -Activity 'Creating backup' -Status $status.alternativePercentage -PercentComplete $percentage
    }
    Start-Sleep -Seconds 5
} while($status.alternativePercentage -ne 'Estimated progress: 100 %')

# Download
if ([bool]($status.PSObject.Properties.Name -match "failedMessage")) {
    throw $status.failedMessage
}

$pathName = $status.fileName
if ($pathName -match "ondemandbackupmanager/download/.+/(.*)") {
    $fileName = $Matches[1]
    Write-Host "Downloading: $fileName to JIRA-backup-$today.zip"
    $progressPreference = 'Continue'
    Invoke-WebRequest -Method Get -Headers @{"Accept"="*/*"} -WebSession $session -Uri "https://$hostname/$pathName" -OutFile (Join-Path -Path $destination -ChildPath "JIRA-backup-$today.zip")
} else {
    Write-Host "Dowlnoading: $pathName to JIRA-backup-$today.zip"
    $progressPreference = 'Continue'
    Invoke-WebRequest "https://$hostname/webdav/backupmanager/$pathName" -Credential $credential -OutFile (Join-Path -Path $destination -ChildPath "JIRA-backup-$today.zip")    
}
