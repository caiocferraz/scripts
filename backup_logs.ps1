# Backup old log files to a compressed archive
$LogPath = "C:\Logs"
$ArchivePath = "C:\Backups\logs_$(Get-Date -Format 'yyyyMMdd').zip"

$OldLogs = Get-ChildItem -Path $LogPath -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

if ($OldLogs.Count -gt 0) {
    $OldLogs | Compress-Archive -DestinationPath $ArchivePath -Force
    $OldLogs | Remove-Item -Force
    Write-Host "Archived $($OldLogs.Count) log files to $ArchivePath"
} else {
    Write-Host "No old log files to archive."
}
