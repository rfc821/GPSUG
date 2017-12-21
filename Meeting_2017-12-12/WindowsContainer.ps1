<#
.Synopsis
    Demo scripts for PowerShell Meetup Nuremberg: Administration of Windows Container with PowerShell
.DESCRIPTION
    script to demostrate usage of Container administration with PowerShell
.OUTPUTS
   none
.NOTES
    Copyright (c) 2017, Sylvio Hellmann All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
    associated documentation files (the "Software"), to deal in the Software without restriction, 
    including without limitation the rights to use, copy, modify, merge, publish, distribute, 
    sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all copies or 
    substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
    NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    Release notes:
    Release date     Description     Author
    02/12/2017       initial Release Sylvio Hellmann (sylvio.hellmann@freenet.de)
.COMPONENT
    Powershell version 4 or higher
    .NET Framework 4.0 or higher
.Link
    https://sylvioh.wordpress.com
#>
# run in single step; Presentation Mode
Exit

#region Install
if (!Get-Service -Name docker) {
    $DockerMinimumVersion = '17.06.1-ee-1'
    $NuGetPackageProviderVersion = '2.8.5.201'
    if (!(Get-PackageProvider -Name "NuGet")) {
        Install-PackageProvider -Name "NuGet" -MinimumVersion $NuGetPackageProviderVersion -Force
    }

    if ($(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' ).ReleaseId -ge 1709) {
        # 1709
        Install-Module DockerProvider
        Install-Package Docker -ProviderName DockerProvider -RequiredVersion 17.06 -Verbose
        # preview for docker Enterprise Preview Edition that support new features
        # Please do not run the preview edition in production.
        Install-Package Docker -ProviderName DockerProvider -RequiredVersion preview

        # The Docker LinuxKit Feature – This is the feature that allows us to run Linux Containers
        [Environment]::SetEnvironmentVariable("LCOW_SUPPORTED", "1", "Machine")
        # disable
        [Environment]::SetEnvironmentVariable("LCOW_SUPPORTED", $null, "Machine")
        # https://github.com/linuxkit

        Get-Command -Module docker

        Get-Service -Name Docker
        Start-Service -Name docker
    }
    else {
        if (!(Get-Module -Name "DockerMsftProvider" -ListAvailable)) {
            Install-Module -Name "DockerMsftProvider" -Repository PSGallery -Force
        }

        # notepad "C:\Program Files\WindowsPowerShell\Modules\DockerMsftProvider\1.0.0.1\DockerMsftProvider.psm1"
        # https://dockermsft.blob.core.windows.net/dockercontainer/DockerMsftIndex.json 
        Get-Package Docker* | Select-Object -Property *
        Install-Package -Name docker -ProviderName DockerMsftProvider -MinimumVersion $DockerMinimumVersion -Force
    }

    Get-WindowsFeature -Name Hyper-V
    Add-WindowsFeature -name Hyper-V
    Restart-Computer -Force
}


#Alternative install with DSC
if (!Get-Service -Name docker) {
    Find-Script -Name "Install-DockerOnWS2016UsingDSC"
    Install-Script -Name Install-DockerOnWS2016UsingDSC
    Install-DockerOnWS2016UsingDSC.ps1
}

#Install manually 
if (!Get-WindowsFeature -Name containers) {
    $null = Install-WindowsFeature -Name containers
}
#from docker
Invoke-WebRequest -UseBasicparsing -Outfile "$Env:TEMP\DockerProvider\docker-17.06.2-ee-6.zip" -Uri 'https://download.docker.com/components/engine/windows-server/17.06/docker-17.06.2-ee-6.zip'
Expand-Archive -Path "$Env:TEMP\DockerProvider\docker-17.06.2-ee-6.zip" -DestinationPath $Env:ProgramFiles
Remove-Item -Force -Path "$Env:TEMP\docker-17.06.2-ee-6.zip"

#from https://mobyproject.org/
# https://master.dockerproject.org/version
$version = (Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/docker/docker/master/VERSION).Content.Trim()
Invoke-WebRequest "https://master.dockerproject.org/windows/x86_64/docker-$($version).zip" -OutFile "$env:TEMP\docker-$($version).zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath $env:ProgramFiles

$env:path += ";$env:ProgramFiles\docker"
$existingMachinePath = [Environment]::GetEnvironmentVariable("Path",[System.EnvironmentVariableTarget]::Machine)
$newPath = "$env:ProgramFiles\docker;" + [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)

dockerd --register-service
Start-Service -Name Docker

#Update/Downgrade Docker - no container restart required
#Upgrade
Install-Package -Name docker -ProviderName DockerMsftProvider -Force
#Downgrade
Install-Package -Name docker -ProviderName DockerMsftProvider -RequiredVersion 17.06.2-ee-5 -Force -Verbose
Restart-Service -Name Docker

# Docker CE für Win10: https://docs.docker.com/docker-for-windows/install/#install-docker-for-windows
# https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe
# docker service and docker client will be installed
# hyperV will be activated --> required multiple reboots
# doesn't work under Windows Server

# Linux Container in Windows Server 2016
<#
* Windows Server 2016 Version 1709 which is the only support OS for running Linux Containers
* Docker Enterprise Edition 17.10 Preview 3
#>
#endregion Install

#region UninstallDocker
Uninstall-Package -Name "Docker" -ProviderName "DockerMsftProvider" -Force
Uninstall-Module -Name "DockerMsftProvider" -Force

        Uninstall-Package Docker -ProviderName DockerProvider -RequiredVersion 17.06 -Verbose
        Uninstall-Module -Name DockerProvider

$service = Get-WmiObject -Class Win32_Service -Filter "Name='docker'"
if ($service) { $service.StopService() }
if ($service) { $service.Delete() }
Stop-Process -Name docker, dockerd
Start-Sleep -s 5
Remove-Item -Recurse -Force "~/AppData/Local/Docker"
Remove-Item -Recurse -Force "~/AppData/Roaming/Docker"
if (Test-Path "C:\ProgramData\Docker") { takeown.exe /F "C:\ProgramData\Docker" /R /A /D Y }
if (Test-Path "C:\ProgramData\Docker") { icacls "C:\ProgramData\Docker\" /T /C /grant Administrators:F }
Remove-Item -Path "C:\ProgramData\docker" -Force -Recurse
Remove-Item -Recurse -Force "C:\Program Files\Docker"
Remove-Item -Path "C:\Windows\system32\config\systemprofile\appData\Roaming\Docker" -Force -Recurse
#endregion UninstallDocker

#region Config
$s = Get-Service -Name Docker
if ($s.status -ne "Running") {
    Start-Service -Name docker
}

Explorer "C:\ProgramData\docker\config"

$DockerConfig = "$Env:ProgramData\docker\config\daemon.json"
$null = New-Item -Path $DockerConfig -Type File -Force
$Conf = @"
{ 
"hosts": ["tcp://0.0.0.0:2375", "npipe://"],
"graph" : "D:\\docker"
}
"@
<#
{
    "authorization-plugins": [],
    "dns": [],
    "dns-opts": [],
    "dns-search": [],
    "exec-opts": [],
    "storage-driver": "",
    "storage-opts": [],
    "labels": [],
    "log-driver": "", 
    "mtu": 0,
    "pidfile": "",
    "graph": "",
    "cluster-store": "",
    "cluster-advertise": "",
    "debug": true,
    "hosts": [],
    "log-level": "",
    "tlsverify": true,
    "tlscacert": "",
    "tlscert": "",
    "tlskey": "",
    "group": "",
    "default-ulimits": {},
    "bridge": "",
    "fixed-cidr": "",
    "raw-logs": false,
    "registry-mirrors": [],
    "insecure-registries": [],
    "disable-legacy-registry": false
}
#>
Add-Content -Path $DockerConfig -Value $Conf
notepad "C:\ProgramData\Docker\config\daemon.json"

Netsh advfirewall firewall add rule name="docker engine" dir=in action=allow protocol=TCP localport=2375

# Docker Log file C:\Users\Administrator\AppData\Local\Docker\log.txt
if (!Test-Path -Path "$($ENV:LOCALAPPDATA)\Docker\log.txt" -PathType Leaf) {
    $null = New-Item -Path "$($ENV:LOCALAPPDATA)\Docker\log.txt" -ItemType File -Force   
}
Restart-Service -Name docker

# Add Container CmdLets to PowerShell
Register-PSRepository -Name dockerps-dev -Sourcelocation "https://ci.appveyor.com/nuget/docker-powershell-dev"
Install-Module -Name "docker" -Repository "dockerps-dev" -Scope Currentuser -AllowClobber
Get-Command -Module docker
#endregion Config

#region FirstSteps
Explorer "C:\Program Files\Docker"
docker --help
docker version
docker info
docker images
Get-ContainerImage -All | ForEach-Object {Remove-ContainerImage -Image $PSitem -Force}

docker search microsoft/mssql

# start first Container
docker pull hello-world:nanoserver
explorer "D:\docker\windowsfilter"

docker container run hello-world:nanoserver
docker container run --isolation=hyperv hello-world:nanoserver

# load more images
docker pull microsoft/nanoserver
Request-ContainerImage -Repository "microsoft/nanoserver" -Tag latest

docker pull microsoft/powershell # docker : image operating system "linux" cannot be used on this platform
docker pull microsoft/powershell:6.0.0-rc-nanoserver-1709
docker pull microsoft/windowsservercore
docker pull microsoft/windowsservercore:10.0.14393.321
docker pull microsoft/windowsservercore-insider
docker pull microsoft/mssql-server-linux:2017-latest #image operating system "linux" cannot be used on this platform
docker pull microsoft/mssql-server-windows-developer
docker pull microsoft/mssql-server-windows-express
docker pull microsoft/iis

docker images
if (!Test-Path -Path d:\images\nano.tar) {
    Remove-Item -Path d:\images\nano.tar
}
docker image save --output d:\images\nano.tar microsoft/nanoserver
Export-ContainerImage -ImageIdOrName microsoft/nanoserver -DestinationFilePath d:\images\nano.tar
docker load -i d:\images\nano.tar

docker run -it microsoft/nanoserver powershell

docker run -name myiis -p 80:80 microsoft/iis
docker exec -it myiis powershell
docker ps
docker inspect myiis
docker inspect --format "{{ .NetworkSettings.Networks.nat.IPAddress }}" myiis
$URL = "http://" + $(docker inspect --format "{{ .NetworkSettings.Networks.nat.IPAddress }}" myiis)
& "C:\Program Files\Internet Explorer\iexplore.exe" $URL
docker stop myiis
docker history myiis
docker diff myiis
docker rm myiis

# with powershell
Get-Command -Module docker | Select-Object -Property Name
$Container = New-Container -Name Test2 -ImageIdOrName "microsoft/windowsservercore"
$Container | Select-Object -Property *
Start-Container $Container
Get-ContainerImage | Select-Object -Property *
Get-Container | Where-Object {$PSItem.Names -match 'Test'} | Remove-Container
Get-Container | Get-ContainerDetail
Get-Container
ipconfig
Get-Process
Enter-PSSession -ContainerId $((Get-Container)[1].ID) -RunAsAdministrator
ipconfig
Get-Process
Exit-PSSession
Get-Process -Name csrss
#endregion FirstSteps

Start-Container -ContainerIdOrName Test
Get-Container

#region TroubleShooting
# (Invoke-Webrequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/MicrosoftDocs/Virtualization-Documentation/live/windows-server-container-tools/Debug-ContainerHost/Debug-ContainerHost.ps1").Content
Invoke-Expression -Command (Invoke-Webrequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/MicrosoftDocs/Virtualization-Documentation/live/windows-server-container-tools/Debug-ContainerHost/Debug-ContainerHost.ps1") -Verbose

# docker messages in Eventlogs
@"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application\docker]
"CustomSource"=dword:00000001
"EventMessageFile"="C:\\Program Files\\docker\\dockerd.exe"
"TypesSupported"=dword:00000007
"@ | Set-content "$Env:TEMP\EWT_Docker.reg"
Invoke-Item -Path  "$Env:TEMP\EWT_Docker.reg"

Get-EventLog -LogName Application -Source Docker -After (Get-Date).AddMinutes(-5) | Sort-Object Time 

# Service infos
sc.exe qc docker
# enable debug
sc.exe config docker binpath= "\"C:\Program Files\Docker\dockerd.exe\" --run-service -D"
dockerd -D

docker service logs --details SERVICE
#endregion TroubleShooting

#region CreateNewImage
New-Item -Path "$Env:Temp\myfirstimage" -ItemType directory | Set-Location
@"
FROM microsoft/nanoserver
CMD echo Hello World
"@ | Set-Content -Path "Dockerfile" -Force
docker build -t myfirstimage .
docker run --name nano myfirstimage
docker stop nano
docker rm nano

$iisfolder = New-Item -Path "$Env:Temp\IISContainer" -ItemType Directory
if ($iisfolder) {
@"
FROM microsoft/iis
	MAINTAINER Sylvio Hellmann
	RUN mkdir C:\site
    SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
	RUN powershell -NoProfile -Command \
	    Import-module IISAdministration; \
	    New-IISSite -Name "Site" -PhysicalPath C:\site -BindingInformation "*:8080:"
	COPY index.html C:\site
	EXPOSE 8080
    # ADD content/ /site
"@ | Out-File -FilePath "$($iisfolder.FullName)\dockerfile" -Encoding ascii
    "<HTML><BODY><P>Testseite</P></BODY></HTML>" | Out-File -FilePath "$($iisfolder.FullName)\index.html"
    Set-Location -Path $iisfolder.FullName
    docker build -t mysecondimage .
    docker run -d --name myiis2 -p 8080:8080 mysecondimage
}
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' myiis2
docker inspect --format "{{ .NetworkSettings.Networks.nat.IPAddress }}" myiis2
$URL = "http://" + $(docker inspect --format "{{ .NetworkSettings.Networks.nat.IPAddress }}" myiis2) + ":8080"
& "C:\Program Files\Internet Explorer\iexplore.exe" $URL

Start-Sleep -Seconds 60
docker stop myiis2
docker rm myiis2
docker rmi mysecondimage
Set-Location -Path "$Env:UserProfile"
Remove-Item -Path $iisfolder.FullName -Recurse -Force

# load image in docker cloud repository
$DOCKER_ID_USER="shellmann"
docker login -u $DOCKER_ID_USER
docker tag myfirstimage $DOCKER_ID_USER/myfirstimage
docker push "$DOCKER_ID_USER/myfirstimage:latest"
docker rmi myfirstimage

docker pull "$DOCKER_ID_USER/myfirstimage:latest"

# not working curre
docker run --name sylvio microsoft/nanoserver
Stop-Container -ContainerIdOrName sylvio
get-command -Module docker
Start-Container -ContainerIdOrName sylvio
docker run -it --isolation=hyperv microsoft/nanoserver cmd
#endregion CreateNewImage

# https://github.com/aspnet/MusicStore

#region ResourceLimitation
docker run -ti --c 512 agileek/cpuset-test             # 50% of CPU usage
docker run -ti --cpuset-cpus=0,4,6 agileek/cpuset-test # Core 0, 4 and 6 active
docker run -it -m 300M ubuntu:14.04 /bin/bash # memory limitation to 300 MB
#endregion ResourceLimitation