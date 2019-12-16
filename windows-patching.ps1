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

# ---- Download module in zip format
$url =
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output) 

# ---- Unblock the zip

Install-Module -Name PSWindowsUpdate

get-wulist -Category "Security"
get-wulist -Category "Critical"
