# Evaluate the number of patches necessary and approximate downtime
# Make a powershell script to do this
# ***** It needs to:
# - count patches on endpoint (at beginning and end)
# - have last installed date for patches
# - reboot pending
# - see what patches are publicly available
# - what needs to be applied to endpoint (critical, security)
# - install patches
# - approximate downtime (1 seconds per 10 mb?)


# ***** It would be cool to add:
# - log the actual downtime so you can guesstimate future patch windows better
# - accept a KB article as param so that it can be installed directly
# - sum the size of updates and return as output

# A script will run on the workstation or server. It will do everything related to patching (inventory, installed, reboot)
# Script INPUT: 
# Inventory flag (default, read-only, don't make any changes)
# Install flag (Install missing patches {critical and security by default})
# Reboot flag (reboot immediately after patches install, reboot at datetime)
# Script OUTPUT:
# Number of already installed patches,
# Number of patches that can be installed (Critical and security by default if available, otherwise all patches available),
# Reboot pending true/false,
# Reboot scheduled datetime,

Param(
    [Parameter(Position=0)]
    [string]$mode="Inventory", # Options: Inventory, Install

    [Parameter(Position=1)]
    [string]$rebootBehavior="Suppress", # Options: Suppress, NextWindow {Sa-Su 2am-5am}, NextSafeWindow {Su 2am-5am}

    [Parameter()]
    [switch]$quiet # Disables reporting/script output
)


# ------------------------------------------- INSTALL AND SETUP THE PSWINDOWSUPDATE MODULE
# ---- Download module in *.NUPKG format, rename as *.zip
$url = 'https://www.powershellgallery.com/api/v2/package/PSWindowsUpdate/2.1.1.2'
$wc = New-Object System.Net.WebClient
$downloadedModule = "C:\temp\pswindowsupdate.2.1.1.2.zip"
$wc.DownloadFile($url, $downloadedModule) 

# ---- Unblock the zip/NUPKG
Unblock-File $downloadedModule

# ---- Unzip the zipped module
$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($downloadedModule)
$location = "C:\temp\PSWindowsUpdate"
mkdir $location
$destinationFolder = $shell.NameSpace($location)

$copyFlags = 0x00
$copyFlags += 0x04 # Hide progress dialogs
$copyFlags += 0x10 # Overwrite existing files

$destinationFolder.CopyHere($zipFile.Items(), $copyFlags)

# ---- Remove irrelevant files
# Not yet shown to be a necessary step

# ---- Copy module folder to expected module paths
$paths = $env:psmodulepath.split(";")
Copy-Item -Path $location -Destination $paths[2] -Container -Recurse

# ---- Import module so we can actually do some work now
Import-Module -Name PSWindowsUpdate

# ------------------------------------------- -MODE "INVENTORY"
# ---- inventory
# - see what patches are publicly available
# - what needs to be applied to endpoint (critical, security)
$securityPatches = get-wulist -Category "Security"
$criticalPatches = get-wulist -Category "Critical"
$installedPatches = get-wulist -IsInstalled
$installedSecurityPatches = get-wulist -Category "Security" -IsInstalled
$installedCriticalPatches = get-wulist -Category "Critical" -IsInstalled

# ***** It needs to:
# - count patches on endpoint (at beginning and end)
$preSessionInstalledPatches = $installedPatches.count
$preSessionInstallablePatches = ($securityPatches.count + $criticalPatches.count)

# - have last installed date for patches
# Does not currently appear to be feasible. Skipping for now (12/17/19)

# - reboot pending test (BEFORE PATCHING)
# https://4sysops.com/archives/use-powershell-to-test-if-a-windows-server-is-pending-a-reboot/
$preSessionRebootPending = $false
$pendingRebootTests = @(
    @{
        Name = 'RebootPending'
        Test = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'  Name 'RebootPending' -ErrorAction Ignore }
        TestType = 'ValueExists'
    }
    @{
        Name = 'RebootRequired'
        Test = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'  Name 'RebootRequired' -ErrorAction Ignore }
        TestType = 'ValueExists'
    }
    @{
        Name = 'PendingFileRenameOperations'
        Test = { Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Ignore }
        TestType = 'NonNullValue'
    }
)

foreach ($test in $pendingRebootTests) {
    $result = Invoke-Command -ScriptBlock $test.Test
    if ($test.TestType -eq 'ValueExists' -and $result) {
        $preSessionRebootPending = $true
    } elseif ($test.TestType -eq 'NonNullValue' -and $result -and $result.($test.Name)) {
        $preSessionRebootPending = $true
    } else {
        $false
    }
}

# ------------------------------------------- -MODE "INSTALL"
# - install patches
$patchInstallDuration = 0 # Initialize as 0 in case we're in inventory mode

if ($mode -like "*Install*") {   
    # Measure patch installation duration
    $patchInstallStopwatch =  [system.diagnostics.stopwatch]::StartNew()

    if ($securityPatches.count -gt 0){
        Get-WUinstall -Category "Security" -IgnoreReboot -AcceptAll
    }
    if ($criticalPatches.count -gt 0){
        Get-WUinstall -Category "Critical" -IgnoreReboot -AcceptAll
    }

    # Round down the time to the nearest minute
    $patchInstallStopwatch.stop()
    $patchInstallDuration = [math]::Round($patchInstallStopwatch.Elapsed.TotalMinutes,0)
    if ($patchInstallDuration -eq 0) { # If the duration is "0 minutes", set to 1 to allow for consistency in units
        $patchInstallDuration = 1 
    }   
}


# - reboot pending test (POST PATCHING)
# https://4sysops.com/archives/use-powershell-to-test-if-a-windows-server-is-pending-a-reboot/
$postSessionRebootPending = $false

foreach ($test in $pendingRebootTests) {
    $result = Invoke-Command -ScriptBlock $test.Test
    if ($test.TestType -eq 'ValueExists' -and $result) {
        $postSessionRebootPending = $true
    } elseif ($test.TestType -eq 'NonNullValue' -and $result -and $result.($test.Name)) {
        $postSessionRebootPending = $true
    } else {
        $false
    }
}

# - approximate downtime (1 seconds per 10 mb?)
# Not an essential feature. Skipping for now (12/18/19)

# ------------------------------------------- -REBOOTBEHAVIOR "SUPPRESS"
if ($rebootBehavior -like "*suppress*") {
    # Do nothing! Easy peasy.
# ------------------------------------------- -REBOOTBEHAVIOR "NEXTWINDOW"
} elseif ($rebootBehavior -like "*NextWindow*") {
    # NextWindow {Sa-Su 2am-5am}
# ------------------------------------------- -REBOOTBEHAVIOR "NEXTSAFEWINDOW"
} elseif ($rebootBehavior -like "*NextSafeWindow*") {
    # NextSafeWindow {Su 2am-5am}
}

# Script OUTPUT:
# Number of already installed patches,
# Number of patches that can be installed (Critical and security by default if available, otherwise all patches available),
# Reboot pending true/false (pre-session, post-install session)
# Patch install duration
# Reboot scheduled datetime,
if ($disable = $false){
    $content = "$Env:COMPUTERNAME,$preSessionInstalledPatches,$preSessionInstallablePatches,$preSessionRebootPending,$postSessionRebootPending,$patchInstallDuration,$write"
    Out-File -FilePath "C:\Temp\Patch Session Summary.csv" -InputObject $content -Append
}

