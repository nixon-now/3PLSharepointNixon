<#
.SYNOPSIS
    Unified file transfer between SharePoint and SFTP.

.DESCRIPTION
    Supports SP <-> SFTP directions with archival.

.REQUIREMENTS
    - PnP.PowerShell (for SharePoint)
    - WinSCP CLI (for SFTP)
#>

# ====================== CONFIGURATION ======================
$TransferDirection = "SPToSFTP"  # Change as needed

# SharePoint Settings
$SharePointSite         = "https://nixonnow.sharepoint.com/sites/businesscentralchannel"
$SharePointLibrary      = "Shared Documents"
$SPSourceFolder         = "3PL_Jobs/AU/Outbox2"
$SPArchiveFolder        = "3PL_Jobs/AU/Outbox2/Archive"
$SPDestinationFolder    = "3PL_Jobs/AU/Inbox"

# App-only auth
$AppClientId            = "56130117-cc70-43f1-add0-708118ee4a1a"
$TenantId               = "ff290f9e-157e-4ef3-a1e7-2390cdd63076"
$CertPath               = "C:\certs\NixonBCSPIntegration.pfx"
$CertPassword           = ConvertTo-SecureString "PutARealStrongPasswordHere123!" -AsPlainText -Force

# SFTP Settings
$Protocol               = "SFTP"
$FtpHost                = "atlas_sftp.next3pl.com"
$FtpPort                = 22
$FtpUser                = "next3plsftp.nixon"
$FtpPass                = "AZuSjjM84mkqjwB8HcxHG9ZF05euf/91"
$FtpSourceFolder        = "/outbox-converted"
$FtpArchiveFolder       = "/outbox-converted/archived"
$FtpTargetFolder        = "/inbox-converted/order"

# Network Paths
$NetworkSourceFolder    = "\\nix-jobs\ftp\NEXT_AU\Export"
$NetworkArchiveFolder   = "\\nix-jobs\ftp\NEXT_AU\archive"
$NetworkTargetFolder    = "\\nix-jobs\ftp\NEXT_AU\Import"

# Local & Log
$TempFolder             = "C:\Temp\SP_Transfer"
$LogFile                = "C:\Logs\SP_Transfer_AU.txt"

# ====================== UTILITIES ======================

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
    Get-ChildItem -Path $folderPath -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "`t"
    } | ForEach-Object {
        $newName = $_.Name -replace "`t", "_"
        try {
            Rename-Item -Path $_.FullName -NewName $newName -Force
            Write-Log "Renamed file with tab: $($_.Name) -> $newName"
        }
        catch {
            Write-Log "WARNING: Could not rename $($_.Name): $_"
        }
    }
    
    # Fix files with other invalid Windows characters
    Get-ChildItem -Path $folderPath -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '[<>:"/\\|?*]'
    } | ForEach-Object {
        $newName = $_.Name -replace '[<>:"/\\|?*]', '_'
        try {
            Rename-Item -Path $_.FullName -NewName $newName -Force
            Write-Log "Renamed file with invalid chars: $($_.Name) -> $newName"
        }
        catch {
            Write-Log "WARNING: Could not rename $($_.Name): $_"
        }
    }
}

function Cleanup-Temp {
    Get-ChildItem -Path $TempFolder -Filter *.xml -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $TempFolder -Filter winscp_*.log -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $TempFolder -Filter winscp_*.txt -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Log "Temporary files cleaned"
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
        try {
            Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path $TempFolder -FileName $file.Name -AsFile -Force
            Write-Log "Downloaded $($file.Name) to temp"
        }
        catch {
            Write-Log "ERROR: Failed to download $($file.Name): $_"
            continue
        }

        $remoteTarget = "$FtpTargetFolder/$($file.Name)"
        $scriptPath = Join-Path $TempFolder "winscp_script.txt"
        $logPath = Join-Path $TempFolder "winscp_upload_$($file.Name).log"

        $protocolType = if ($isSFTP) { "sftp" } else { "ftp" }
        
        # CORRECTED WinSCP script - proper hostkey format and connection string
       $scriptContent = @"
option batch abort
option confirm off
open sftp://$FtpUser@$FtpHost -hostkey=`"ecdsa-sha2-nistp256 256 YeFqljxSldNJIftmtsCIyMeoT5QafOSHQzt2oYReDj4`" -password=`"$FtpPass`"
put `"$localPath`" `"$remoteTarget`"
exit
"@

        $scriptContent | Out-File -FilePath $scriptPath -Encoding ASCII

        # Execute WinSCP
        Write-Log "Executing WinSCP upload for $($file.Name)..."
        $process = Start-Process -FilePath $WinSCP -ArgumentList "/ini=nul /script=`"$scriptPath`" /log=`"$logPath`"" -Wait -PassThru -NoNewWindow
        $ExitCode = $process.ExitCode

        if ($ExitCode -eq 0) {
            Write-Log "Successfully uploaded $($file.Name) to $protocolType"
            
            # Archive in SharePoint
            try {
                $web = Get-PnPWeb
                $serverRelativeSourceUrl = "$($web.ServerRelativeUrl)/$SharePointLibrary/$SPSourceFolder/$($file.Name)".Replace("//", "/")
                $serverRelativeTargetUrl = "$($web.ServerRelativeUrl)/$SharePointLibrary/$SPArchiveFolder/$($file.Name)".Replace("//", "/")
                
                # Ensure archive folder exists
                try {
                    Resolve-PnPFolder -SiteRelativePath "$SharePointLibrary/$SPArchiveFolder" | Out-Null
                    Write-Log "Verified archive folder exists."
                }
                catch {
                    Write-Log "Archive folder already exists or cannot be created: $_"
                }
                
                Move-PnPFile -SourceUrl $serverRelativeSourceUrl -TargetUrl $serverRelativeTargetUrl -Force -AllowSchemaMismatch
                Write-Log "Archived $($file.Name) in SharePoint"
            }
            catch {
                Write-Log "WARNING: Failed to archive $($file.Name) in SharePoint: $_"
            }
        } else {
            Write-Log "ERROR: Upload failed for $($file.Name) with exit code $ExitCode"
            if (Test-Path $logPath) {
                Write-Log "WinSCP Log for $($file.Name):"
                Get-Content $logPath | ForEach-Object { Write-Log "WinSCP: $_" }
            }
        }

        # Cleanup
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        Remove-Item $localPath -Force -ErrorAction SilentlyContinue
        if (Test-Path $logPath) {
            Remove-Item $logPath -Force -ErrorAction SilentlyContinue
        }
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

    $scriptPath = Join-Path $TempFolder "winscp_download_script.txt"
    $logPath = Join-Path $TempFolder "winscp_download.log"

    # Define known good host key fingerprint (only for SFTP)
    $HostKeyParam = ""
    if ($isSFTP) {
        $PinnedHostKey = 'ecdsa-sha2-nistp256 256 YeFqljxSldNJIftmtsCIyMeoT5QafOSHQzt2oYReDj4='
        $HostKeyParam = "-hostkey=`"$PinnedHostKey`""
    }

    # Create the WinSCP script with robust error handling
    $scriptContent = @"
# Disable all prompts and continue on errors
option batch continue
option confirm off
option transfer binary

# Handle invalid characters in filenames
option rawtransfers on

# Connect
open ${protocolType}://${FtpUser}:${FtpPass}@${FtpHost}:${FtpPort} $HostKeyParam

# Change to local temp directory
lcd "$TempFolder"

# Download files with raw transfers to handle special characters
get -rawtransfers=on "$FtpSourceFolder/*.xml" ".\"

# Move files to archive
mv "$FtpSourceFolder/*.xml" "$FtpArchiveFolder/"
exit
"@

    $scriptContent | Set-Content -Path $scriptPath -Encoding ASCII
    Write-Log "Created WinSCP script: $scriptPath"

    # Execute WinSCP with timeout
    Write-Log "Executing WinSCP download command..."
    $process = Start-Process -FilePath $WinSCP -ArgumentList "/ini=nul /script=`"$scriptPath`" /log=`"$logPath`"" -Wait -PassThru -NoNewWindow
    $ExitCode = $process.ExitCode

    Write-Log "WinSCP exit code: $ExitCode"
    
    # Repair any filenames with invalid characters
    Repair-Filenames -folderPath $TempFolder

    if ($ExitCode -eq 0) {
        $downloadedFiles = Get-ChildItem -Path $TempFolder -Filter *.xml
        if ($downloadedFiles.Count -gt 0) {
            Write-Log "Found $($downloadedFiles.Count) files downloaded"
            foreach ($file in $downloadedFiles) {
                try {
                    Write-Log "Uploading $($file.Name) to SharePoint folder: $SPDestinationFolder"
                    
                    # Remove file if it exists (overwrite functionality)
                    $serverRelativeUrl = "/$SharePointLibrary/$SPDestinationFolder/$($file.Name)"
                    try {
                        Remove-PnPFile -ServerRelativeUrl $serverRelativeUrl -Force -ErrorAction SilentlyContinue
                        Write-Log "Removed existing file: $($file.Name)"
                    }
                    catch {
                        # File doesn't exist or couldn't be removed - continue anyway
                    }
                    
                    # Add the new file
                    Add-PnPFile -Path $file.FullName -Folder "$SharePointLibrary/$SPDestinationFolder"
                    Write-Log "Successfully uploaded $($file.Name) to SharePoint"
                    Remove-Item $file.FullName -Force
                }
                catch {
                    Write-Log "ERROR: Failed to upload $($file.Name) to SharePoint: $_"
                }
            }
        } else {
            Write-Log "No XML files downloaded from $protocolType"
        }
    } else {
        Write-Log "ERROR: WinSCP download failed with exit code $ExitCode"
        if (Test-Path $logPath) {
            Write-Log "WinSCP Log (last 10 lines):"
            Get-Content $logPath -Tail 10 | ForEach-Object { Write-Log "WinSCP: $_" }
        }
    }

    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
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
            
            # Archive in SharePoint
            $web = Get-PnPWeb
            $serverRelativeSourceUrl = "$($web.ServerRelativeUrl)/$SharePointLibrary/$SPSourceFolder/$($file.Name)".Replace("//", "/")
            $serverRelativeTargetUrl = "$($web.ServerRelativeUrl)/$SharePointLibrary/$SPArchiveFolder/$($file.Name)".Replace("//", "/")
            Move-PnPFile -SourceUrl $serverRelativeSourceUrl -TargetUrl $serverRelativeTargetUrl -Force -AllowSchemaMismatch
            Write-Log "Archived $($file.Name) in SharePoint"
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
            # Remove file if it exists (overwrite functionality)
            $serverRelativeUrl = "/$SharePointLibrary/$SPDestinationFolder/$($file.Name)"
            try {
                Remove-PnPFile -ServerRelativeUrl $serverRelativeUrl -Force -ErrorAction SilentlyContinue
                Write-Log "Removed existing file: $($file.Name)"
            }
            catch {
                # File doesn't exist or couldn't be removed - continue anyway
            }
            
            # Add the new file
            Add-PnPFile -Path $file.FullName -Folder "$SharePointLibrary/$SPDestinationFolder"
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
        "SFTPToSP"     { FTPGenericToSP -isSFTP $true }    # This will be called for AU SFTPToSP
        "FTPToSP"      { FTPGenericToSP -isSFTP $false }
        "NetworkToSP"  { NetworkToSP }
        default        { Write-Log "ERROR: Invalid TransferDirection: $TransferDirection" }
    }
} catch {
    Write-Log "ERROR: $_"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
} finally {
    Cleanup-Temp
    Write-Log "=== [$TransferDirection] Job Completed ===`n"
}