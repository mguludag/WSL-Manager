# WSL-Manager
This is PowerShell script for linux distro download and installation to wsl plus adding to Windows Terminal with icon and reset password, shrink vhdx, import/export distro!

## Use

```powershell
Set-ExecutionPolicy RemoteSigned -scope Process -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mguludag/WSL-Manager/main/wslmanager.ps1" -OutFile $pwd/wslmanager.ps1
./wslmanager.ps1
exit
```

## Download
<a href="https://github.com/mguludag/WSL-Manager/releases/latest/download/wslmanager.zip"><img alt="GitHub Releases" src="https://img.shields.io/github/downloads/mguludag/WSL-Manager/latest/total?label=Download%20Script&style=for-the-badge">
  
## Features
- Install distro from local file
- Download and install distro from URL
- Auto install essential utils to distro for create user
- Adding icon to windows terminal menu
- Export any distro to selected path
- Import distro from local file and show choice of set default user
- Reset password of any user

### WSL Manager main menu
<center>
<img src="https://github.com/mguludag/WSL-Manager/blob/main/Screenshot%202023-05-20%20115821.png?raw=true">
</center>

### Icons in Windows Terminal menu
<center>
<img src="https://github.com/mguludag/WSL-Distro-Downloader-Installer/blob/main/wintermwicons.png?raw=true">
</center>

## Installation
1. Unzip and open wslmanager.bat and follow the instructions!
