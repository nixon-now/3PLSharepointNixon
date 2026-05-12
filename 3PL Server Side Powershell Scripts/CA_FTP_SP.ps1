<#
.SYNOPSIS
    Unified file transfer between SharePoint and FTP/SFTP/Network.
.DESCRIPTION
    Supports SP <-> FTP, SFTP, Network folder directions with archival.
.REQUIREMENTS
    - PnP.PowerShell (for SharePoint)
    - WinSCP CLI (for FTP/SFTP)
#>

# ====================== CONFIGURATION ======================
$TransferDirection = "FTPToSP"  # Change as needed

# SharePoint Settings
$SharePointSite         = "https://nixonnow.sharepoint.com/sites/businesscentralchannel"
$SharePointLibrary      = "Shared Documents"
$SPSourceFolder         = "3PL_Jobs/CA/Outbox2"
$SPArchiveFolder        = "3PL_Jobs/CA/Archive"
$SPDestinationFolder    = "3PL_Jobs/CA/Inbox"

# App-only auth
$AppClientId            = "56130117-cc70-43f1-add0-708118ee4a1a"
$TenantId               = "ff290f9e-157e-4ef3-a1e7-2390cdd63076"
$CertPath               = "C:\certs\NixonBCSPIntegration.pfx"
$CertPassword           = ConvertTo-SecureString "PutARealStrongPasswordHere123!" -AsPlainText -Force

# FTP/SFTP Settings
$Protocol               = "FTP"
$FtpHost                = "exch.i2i.ca"
$FtpPort                = 21
$FtpUser                = "nixon"
$FtpPass                = "j4Hs9HwtB3i9uft2"
$FtpSourceFolder        = "/processed/dayend"
$FtpArchiveFolder       = "/shipped/archive"
$FtpTargetFolder        = "/ship"

# Network Paths
$NetworkSourceFolder    = "\\nix-jobs\ftp\ItoI_CA\Export\ship"
$NetworkArchiveFolder   = "\\nix-jobs\ftp\ItoI_CA\Export\ship\archive"
$NetworkTargetFolder    = "\\nix-jobs\ftp\ItoI_CA\Import\ship"

# Local & Log
$TempFolder             = "C:\Temp\SP_Transfer"
$LogFile                = "C:\Logs\SP_Transfer.log"

# ====================== UTILITIES ======================
# Import the required module for SharePoint commands
Import-Module PnP.PowerShell -ErrorAction Stop

function Write-Log {
    param ([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts - $msg" | Tee-Object -FilePath $LogFile -Append
}

function Connect-SharePoint {
    Write-Log "Connecting to SharePoint using app-only certificate"
    try {
        Connect-PnPOnline -Url $SharePointSite -Tenant $TenantId -ClientId $AppClientId -CertificatePath $CertPath -CertificatePassword $CertPassword
        Write-Log "Successfully connected to SharePoint"
    }
    catch {
        Write-Log "ERROR: Failed to connect to SharePoint: $_"
        throw
    }
}

function Ensure-Folder-Exists {
    param($folderPath)
    if (!(Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        Write-Log "Created directory: $folderPath"
    }
}

function Repair-Filenames {
    param($folderPath)
    
    # Fix files with tab characters
    Get-ChildItem -Path $folderPath -Filter "*`t*" -ErrorAction SilentlyContinue | ForEach-Object {
        $newName = $_.Name -replace "`t", "_"
        Rename-Item -Path $_.FullName -NewName $newName -Force
        Write-Log "Renamed file with tab: $($_.Name) -> $newName"
    }
    
    # Fix files with other invalid Windows characters
    Get-ChildItem -Path $folderPath -Filter "*" -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '[<>:"/\\|?*]'
    } | ForEach-Object {
        $newName = $_.Name -replace '[<>:"/\\|?*]', '_'
        Rename-Item -Path $_.FullName -NewName $newName -Force
        Write-Log "Renamed file with invalid chars: $($_.Name) -> $newName"
    }
}

function Cleanup-Temp {
    Get-ChildItem -Path $TempFolder -Filter *.xml -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $TempFolder -Filter winscp_*.log -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $TempFolder -Filter winscp_*.txt -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Log "Temporary files cleaned"
}
# ====================== NEW FUNCTION ======================
function Move-ImportedFilesToArchive {
    Connect-SharePoint
    Write-Log "Checking for imported files in SharePoint Inbox"
    
    # Get all files ending with "imported.xml" in the Inbox
    $importedFiles = Get-PnPFolderItem -Folder "$SharePointLibrary/$SPDestinationFolder" -ItemType File | 
                    Where-Object { $_.Name -like "*imported.xml" }
    
    if ($importedFiles.Count -eq 0) {
        Write-Log "No imported.xml files found in Inbox"
        return
    }
    
    Write-Log "Found $($importedFiles.Count) imported files to archive"
    
    foreach ($file in $importedFiles) {
        try {
            $sourceUrl = "$SharePointLibrary/$SPDestinationFolder/$($file.Name)"
            $targetUrl = "$SharePointLibrary/$SPArchiveFolder/$($file.Name)"
            
            # Move the file to archive
            Move-PnPFile -ServerRelativeUrl $sourceUrl -TargetUrl $targetUrl -OverwriteIfAlreadyExists -Force
            Write-Log "Moved $($file.Name) to Archive"
        }
        catch {
            Write-Log "ERROR: Failed to move $($file.Name) to Archive: $_"
        }
    }
}

# ====================== DIRECTIONAL FLOWS ======================
function SPToFTPGeneric {
    param($isSFTP = $true)
    
    Connect-SharePoint
    Write-Log "Checking folder: $SharePointLibrary/$SPSourceFolder"
    $files = Get-PnPFolderItem -Folder "$SharePointLibrary/$SPSourceFolder" -ItemType File | Where-Object { $_.Name -like "*.xml" }
    if ($files.Count -eq 0) { Write-Log "No XML files found in SP"; return }

    $WinSCP = "C:\Program Files (x86)\WinSCP\WinSCP.exe"
    if (!(Test-Path $WinSCP)) { $WinSCP = "C:\Program Files\WinSCP\WinSCP.exe" }
    if (!(Test-Path $WinSCP)) { Write-Log "ERROR: WinSCP.exe not found."; return }

    foreach ($file in $files) {
        $localPath = Join-Path $TempFolder $file.Name
        Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path $TempFolder -FileName $file.Name -AsFile -Force
        Write-Log "Downloaded $($file.Name) to temp"

        $remoteTarget = "$FtpTargetFolder/$($file.Name)"
        $scriptPath = Join-Path $TempFolder "winscp_script.txt"

        $protocolType = if ($isSFTP) { "sftp" } else { "ftp" }
        
        $scriptContent = @"
option batch abort
option confirm off
open ${protocolType}://${FtpUser}:${FtpPass}@${FtpHost}:${FtpPort}
put "$localPath" "$remoteTarget"
exit
"@

        $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII
        
        # Execute WinSCP with timeout
        $process = Start-Process -FilePath $WinSCP -ArgumentList "/ini=nul /script=`"$scriptPath`" /log=`"$TempFolder\winscp.log`"" -Wait -PassThru -NoNewWindow
        $ExitCode = $process.ExitCode

        if ($ExitCode -eq 0) {
            Write-Log "Uploaded $($file.Name) to $protocolType"
        } else {
            Write-Log "ERROR: Upload failed for $($file.Name) with exit code $ExitCode"
        }

        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

function FTPGenericToSP {
    param($isSFTP = $true)
    
    Connect-SharePoint
    $protocolType = if ($isSFTP) { "sftp" } else { "ftp" }
    Write-Log "Starting $protocolType download from $FtpSourceFolder"

    # Ensure temp directory exists
    Ensure-Folder-Exists $TempFolder

    $WinSCP = "C:\Program Files (x86)\WinSCP\WinSCP.exe"
    if (!(Test-Path $WinSCP)) { $WinSCP = "C:\Program Files\WinSCP\WinSCP.exe" }
    if (!(Test-Path $WinSCP)) { 
        Write-Log "ERROR: WinSCP.exe not found." 
        return 
    }

    # Step 1: Download files only
    $downloadScriptPath = Join-Path $TempFolder "winscp_download.txt"
    $downloadLogPath = Join-Path $TempFolder "winscp_download.log"

    $downloadScriptContent = @"
option batch continue
option confirm off
option transfer binary
option rawtransfers on

open ${protocolType}://${FtpUser}:${FtpPass}@${FtpHost}:${FtpPort}
lcd "$TempFolder"
get "$FtpSourceFolder/*.xml" ".\"
exit
"@

    $downloadScriptContent | Set-Content -Path $downloadScriptPath -Encoding ASCII
    Write-Log "Created download script: $downloadScriptPath"

    Write-Log "Executing WinSCP download..."
    $downloadProcess = Start-Process -FilePath $WinSCP -ArgumentList "/ini=nul /script=`"$downloadScriptPath`" /log=`"$downloadLogPath`"" -Wait -PassThru -NoNewWindow
    $downloadExitCode = $downloadProcess.ExitCode

    Write-Log "Download exit code: $downloadExitCode"

    # Step 2: Repair filenames
    Repair-Filenames -folderPath $TempFolder

    # Step 3: Upload to SharePoint
    $downloadedFiles = Get-ChildItem -Path $TempFolder -Filter *.xml
    if ($downloadedFiles.Count -gt 0) {
        Write-Log "Found $($downloadedFiles.Count) files downloaded"
        foreach ($file in $downloadedFiles) {
    try {
        Write-Log "Uploading $($file.Name) to SharePoint folder: $SPDestinationFolder"
        
        # Remove file if it exists (overwrite functionality)
        #$serverRelativeUrl = "/$SharePointLibrary/$SPDestinationFolder/$($file.Name)"
        #try {
        #    Remove-PnPFile -ServerRelativeUrl $serverRelativeUrl -Force -ErrorAction SilentlyContinue
        #    Write-Log "Removed existing file: $($file.Name)"
        #}
        #catch {
        #    # File doesn't exist or couldn't be removed - continue anyway
        #}
        
        # Add the new file
        Add-PnPFile -Path $file.FullName -Folder "$SharePointLibrary/$SPDestinationFolder"
        Write-Log "Successfully uploaded $($file.Name) to SharePoint"
        Remove-Item $file.FullName -Force
    }
    catch {
        Write-Log "ERROR: Failed to upload $($file.Name) to SharePoint: $_"
    }
}
        # Step 4: Archive files on FTP (only if download and upload succeeded)
        $archiveScriptPath = Join-Path $TempFolder "winscp_archive.txt"
        $archiveLogPath = Join-Path $TempFolder "winscp_archive.log"

        $archiveScriptContent = @"
option batch continue
option confirm off

open ${protocolType}://${FtpUser}:${FtpPass}@${FtpHost}:${FtpPort}

# Create archive directory if it doesn't exist
mkdir "$FtpArchiveFolder"

# Move files to archive
mv "$FtpSourceFolder/*.xml" "$FtpArchiveFolder/"
exit
"@

        $archiveScriptContent | Set-Content -Path $archiveScriptPath -Encoding ASCII
        Write-Log "Created archive script: $archiveScriptPath"

        Write-Log "Archiving files on FTP server..."
        $archiveProcess = Start-Process -FilePath $WinSCP -ArgumentList "/ini=nul /script=`"$archiveScriptPath`" /log=`"$archiveLogPath`"" -Wait -PassThru -NoNewWindow
        $archiveExitCode = $archiveProcess.ExitCode

        Write-Log "Archive exit code: $archiveExitCode"

        if ($archiveExitCode -ne 0 -and (Test-Path $archiveLogPath)) {
            Write-Log "Archive log (last 10 lines):"
            Get-Content $archiveLogPath -Tail 10 | ForEach-Object { Write-Log "Archive: $_" }
        }

        Remove-Item $archiveScriptPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "No XML files downloaded from $protocolType"
        
        # Check if download actually failed or just no files
        if ($downloadExitCode -ne 0 -and (Test-Path $downloadLogPath)) {
            Write-Log "Download log (last 10 lines):"
            Get-Content $downloadLogPath -Tail 10 | ForEach-Object { Write-Log "Download: $_" }
        }
    }

    Remove-Item $downloadScriptPath -Force -ErrorAction SilentlyContinue
}

function SPToNetwork {
    Connect-SharePoint
    Write-Log "Checking folder: $SharePointLibrary/$SPSourceFolder"
    $files = Get-PnPFolderItem -Folder "$SharePointLibrary/$SPSourceFolder" -ItemType File | Where-Object { $_.Name -like "*.xml" }
    
    # Ensure network folder exists
    Ensure-Folder-Exists $NetworkTargetFolder
    
    foreach ($file in $files) {
        try {
            $targetPath = Join-Path $NetworkTargetFolder $file.Name
            Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path $NetworkTargetFolder -FileName $file.Name -AsFile -Force
            Write-Log "Copied $($file.Name) to network"
        }
        catch {
            Write-Log "ERROR: Failed to process $($file.Name): $_"
        }
    }
}

function NetworkToSP {
    Connect-SharePoint
    
    # Ensure network folders exist
    Ensure-Folder-Exists $NetworkSourceFolder
    Ensure-Folder-Exists $NetworkArchiveFolder
    
    $files = Get-ChildItem -Path $NetworkSourceFolder -Filter *.xml
    foreach ($file in $files) {
        try {
            Add-PnPFile -Path $file.FullName -Folder "$SharePointLibrary/$SPDestinationFolder" -Overwrite
            Write-Log "Uploaded $($file.Name) to SP"
            
            $archivePath = Join-Path $NetworkArchiveFolder $file.Name
            Move-Item -Path $file.FullName -Destination $archivePath -Force
            Write-Log "Archived $($file.Name) in network"
        }
        catch {
            Write-Log "ERROR: Failed to process $($file.Name): $_"
        }
    }
}

# ====================== MAIN ======================
Write-Log "`n=== [$TransferDirection] Job Started ==="

# Ensure folders exist
Ensure-Folder-Exists $TempFolder
Ensure-Folder-Exists (Split-Path $LogFile -Parent)

try {
    switch ($TransferDirection) {
        "SPToSFTP"     { SPToFTPGeneric -isSFTP $true }
        "SPToFTP"      { SPToFTPGeneric -isSFTP $false }
        "SPToNetwork"  { SPToNetwork }
        "SFTPToSP"     { FTPGenericToSP -isSFTP $true }
        "FTPToSP"      { FTPGenericToSP -isSFTP $false }
        "NetworkToSP"  { NetworkToSP }
        default        { Write-Log "ERROR: Invalid TransferDirection: $TransferDirection" }
    }
	# NEW: Always check for and move imported files to archive after any transfer operation
    Move-ImportedFilesToArchive
} catch {
    Write-Log "ERROR: $_"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
} finally {
    Cleanup-Temp
    Write-Log "=== [$TransferDirection] Job Completed ===`n"
}