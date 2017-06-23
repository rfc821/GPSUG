return

# --------------------------
# NuGet Fileshare Repository
# --------------------------

    # server01 = fileshare
    # server02 = client
    # "$home\Desktop\Learn-PowerShell-with-Donuts" = newly created module
    # '\\server01.example.com\PSRepository' = fileshare repository

# Create new fileshare repository (demo-repository)
Register-PSRepository -Name Demo -SourceLocation '\\server01.example.com\PSRepository' -InstallationPolicy Trusted
Get-PSRepository

# Test module manifest
Test-ModuleManifest -Path "$home\Desktop\Learn-PowerShell-with-Donuts\Learn-PowerShell-with-Donuts.psd1"

# Show module manifest
psEdit "$home\Desktop\Learn-PowerShell-with-Donuts\Learn-PowerShell-with-Donuts.psd1"

$path = "$home\Desktop\Learn-PowerShell-with-Donuts\Learn-PowerShell-with-Donuts.psd1"
$content = gc -Path $path -Raw
Invoke-Expression $content

# Publish module on demo-depository
Publish-Module -Name "$home\Desktop\Learn-PowerShell-with-Donuts" -Repository Demo

# Find module on demo-depository
Get-ChildItem '\\server01.example.com\PSRepository'
Find-Package -Source Demo

# Wich modules are localy installed?
Get-Module -ListAvailable
Get-Module -ListAvailable | Where Name -like '*Donut*'

# Install module from demo-depository
Install-Module -Name Learn-PowerShell-with-Donuts -Repository Demo -Scope CurrentUser -Force

# ----------
# Chocolatey
# ----------

# Install Chocolatey provider
Install-PackageProvider -Name Chocolatey
Get-PackageProvider 
Find-Package -Source Chocolatey

# Have fun
# Find-Package -Source Chocolatey | Install-Package