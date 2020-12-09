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


echo "If you see *Execution Policy Change* prompt select [Yes]"
echo ""
echo "GETTING ADMIN RIGHTS"
echo ""
#param([switch]$Elevated)
function Check-Admin {
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Check-Admin) -eq $false)  {
if ($elevated)
{
# could not elevate, quit
}
 
else {
 
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}
exit
}

echo "Checking existing WSL installations..."
$ex=wsl --list >$null

if($ex -Contains "Fedora-33 (Default)" -or "Fedora-33"){
	wsl --unregister Fedora-33 >$null
}

Remove-Item "$env:LOCALAPPDATA/Programs/Fedora" -Filter * -Recurse -ErrorAction Ignore >$null
echo ""
echo "Created $env:LOCALAPPDATA/Programs/Fedora directory"
New-Item -ItemType directory -Path "$env:LOCALAPPDATA/Programs/Fedora" >$null

echo ""
echo "Installing 7Zip4Powershell for extract xz archive. Please answer [Yes] for installation."
Install-Module -Name 7Zip4Powershell

echo ""
echo "Downloading Fedora 33 Image"
Import-Module BitsTransfer
Start-BitsTransfer -Source "https://raw.githubusercontent.com/fedora-cloud/docker-brew-fedora/33/x86_64/fedora-33.20201124-x86_64.tar.xz" -Destination "$env:LOCALAPPDATA/Programs/Fedora/fedora.tar.xz"

Start-BitsTransfer -Source "https://getfedora.org/static/images/favicon.ico" -Destination "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState\fedora.ico"


echo ""
echo "Extracting..."
Expand-7Zip $env:LOCALAPPDATA\Programs\Fedora\fedora.tar.xz $env:LOCALAPPDATA\Programs\Fedora\

echo ""
echo "Installing Fedora 33..."
wsl.exe --import Fedora-33 $env:LOCALAPPDATA/Programs/Fedora/RootFS $env:LOCALAPPDATA/Programs/Fedora/fedora.tar

echo ""
echo "Opening Fedora 33 as root user"
wsl -d Fedora-33 dnf update -y
wsl -d Fedora-33 dnf install -y wget curl sudo ncurses dnf-plugins-core dnf-utils passwd findutils
wsl -d Fedora-33 dnf copr enable -y trustywolf/wslu
wsl -d Fedora-33 dnf install -y wslu

echo ""
$username = Read-Host -Prompt 'Please enter your username'
wsl -d Fedora-33 useradd -G wheel $username
wsl -d Fedora-33 passwd $username
$uid = wsl -d Fedora-33 -u $username id -u

echo ""
echo "Registering to Windows Terminal..."
Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq Fedora-33  | Set-ItemProperty -Name DefaultUid -Value $uid

((Get-Content "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json") -replace '"name": "Fedora-33",' , '"name": "Fedora-33", "icon": "ms-appdata:///roaming/fedora.ico",') | set-content -path "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

echo "Done."
