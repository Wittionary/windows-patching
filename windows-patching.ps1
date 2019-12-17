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

# ---- Download module in *.NUPKG format, rename as *.zip
$url = 'https://www.powershellgallery.com/api/v2/package/PSWindowsUpdate/2.1.1.2'
$wc = New-Object System.Net.WebClient
$downloadedModule = "C:\users\lpsadmin\pswindowsupdate.2.1.1.2.zip"
$wc.DownloadFile($url, $downloadedModule) 

# ---- Unblock the zip/NUPKG
Unblock-File $downloadedModule

# ---- Unzip the zipped module
$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($downloadedModule)
$location = "C:\users\lpsadmin\PSWindowsUpdate"
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

# - have last installed date for patches
# Does not currently appear to be feasible. Skipping for now (12/17/19)

# - reboot pending
# https://4sysops.com/archives/use-powershell-to-test-if-a-windows-server-is-pending-a-reboot/

# - install patches
# - approximate downtime (1 seconds per 10 mb?)
