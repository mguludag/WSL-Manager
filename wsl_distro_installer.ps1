#                   GNU AFFERO GENERAL PUBLIC LICENSE
#                       Version 3, 19 November 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.
#
#                            Preamble
#
#  The GNU Affero General Public License is a free, copyleft license for
#software and other kinds of works, specifically designed to ensure
#cooperation with the community in the case of network server software.
#
#  The licenses for most software and other practical works are designed
#to take away your freedom to share and change the works.  By contrast,
#our General Public Licenses are intended to guarantee your freedom to
#share and change all versions of a program--to make sure it remains free
#software for all its users.
#
#  When we speak of free software, we are referring to freedom, not
#price.  Our General Public Licenses are designed to make sure that you
#have the freedom to distribute copies of free software (and charge for
#them if you wish), that you receive source code or can get it if you
#want it, that you can change the software or use pieces of it in new
#free programs, and that you know you can do these things.
#
#  Developers that use our General Public Licenses protect your rights
#with two steps: (1) assert copyright on the software, and (2) offer
#you this License which gives you legal permission to copy, distribute
#and/or modify the software.
#
#  A secondary benefit of defending all users' freedom is that
#improvements made in alternate versions of the program, if they
#receive widespread use, become available for other developers to
#incorporate.  Many developers of free software are heartened and
#encouraged by the resulting cooperation.  However, in the case of
#software used on network servers, this result may fail to come about.
#The GNU General Public License permits making a modified version and
#letting the public access it on a server without ever releasing its
#source code to the public.
#
#  The GNU Affero General Public License is designed specifically to
#ensure that, in such cases, the modified source code becomes available
#to the community.  It requires the operator of a network server to
#provide the source code of the modified version running there to the
#users of that server.  Therefore, public use of a modified version, on
#a publicly accessible server, gives the public access to the source
#code of the modified version.
#
#  An older license, called the Affero General Public License and
#published by Affero, was designed to accomplish similar goals.  This is
#a different license, not a version of the Affero GPL, but Affero has
#released a new version of the Affero GPL which permits relicensing under
#this license.
#
#  The precise terms and conditions for copying, distribution and
#modification follow.

$SetupFolder = "$env:LOCALAPPDATA/Programs"
$TermIconPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState"
$TermSettingsPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$DistroName = Read-Host -Prompt 'Input your distro name'
$DistroPath = "$SetupFolder/$DistroName"
$DistroIcon = Read-Host -Prompt 'Input your distro icon name or drag-drop icon here'
$DistroIconFilename = Split-Path $DistroIcon -leaf
Copy-Item -Path $DistroIcon -Destination $TermIconPath
$PackageManName = Read-Host -Prompt 'Input your package manager name (example: fedora->dnf, rhel->yum, arch->pacman, ubuntu->apt...)'
$DistroURL = Read-Host -Prompt 'Input your distro url (tar.xz link) or path of local file (alternatively drag-drop the file here)'
$DistroFilename = $DistroName+".tar.xz"

echo ""
echo "Checking existing WSL installations..."
$ex=wsl --list >$null

if($ex -Contains "$DistroName (Default)" -or "$DistroName"){
	echo ""
	echo "Unregistering same name WSL installations..."
	wsl --unregister $DistroName >$null
}

if(Test-Path $DistroPath){
	Remove-Item "$DistroPath" -Filter * -Recurse -ErrorAction Ignore >$null
}
else{
	echo ""
	echo "Created $DistroPath directory"
	New-Item -ItemType directory -Path "$DistroPath" >$null
}

echo ""
echo "Downloading 7Zip4Powershell for extract xz archive..."
Save-Module -Name 7Zip4Powershell -Path $DistroPath
$ver=Get-ChildItem -Path $DistroPath/7Zip4Powershell/ -Name
Import-Module $DistroPath/7Zip4Powershell/$ver/7Zip4PowerShell.psd1

if($DistroURL -Contains "http"){
	echo ""
	echo "Downloading $DistroName Image"
	Import-Module BitsTransfer
	Start-BitsTransfer -Source "$DistroURL" -Destination "$DistroPath/$DistroName.tar.xz"
}
else{
echo ""
	echo "Copying $DistroName Image"
	$DistroFilename = Split-Path $DistroURL -leaf
	Copy-Item -Path $DistroURL -Destination "$DistroPath/"
}


echo ""
echo "Extracting..."
Expand-7Zip $DistroPath/$DistroFileName $DistroPath/

$DistroFileName=$DistroFileName.Replace(".xz","")
echo ""
echo "Installing $DistroName..."
wsl.exe --import $DistroName $DistroPath/RootFS $DistroPath/$DistroFileName

echo ""
echo "Opening $DistroName as root user"
wsl -d $DistroName $PackageManName update -y
wsl -d $DistroName $PackageManName install -y wget curl sudo ncurses passwd findutils


echo ""
$username = Read-Host -Prompt 'Please enter your username'
wsl -d $DistroName useradd -G wheel $username
wsl -d $DistroName passwd $username
$uid = wsl -d $DistroName -u $username id -u

echo ""
echo "Registering to Windows Terminal..."
Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq $DistroName  | Set-ItemProperty -Name DefaultUid -Value $uid

if($DistroIconFilename.Length>3){
((Get-Content "$TermSettingsPath\settings.json") -replace '"name": "$DistroName",' , '"name": "$DistroName", "icon": "ms-appdata:///roaming/$DistroIconFilename",') | set-content -path "TermSettingsPath\settings.json"
}
echo "Done."

Start-Sleep -s 10