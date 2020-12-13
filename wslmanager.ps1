function mainfn {
	do {
		Clear-Host
		Write-Host "Welcome to WSL Distro Manager"
		Write-Host "------------------------------------------------------------"

		$Global:index = -1
		$Global:name = @()
		$Global:path = @()
		
		Write-Host "Installed WSL Distributions"
		Write-Host "------------------------------------------------------------"
		((Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object { Get-ItemProperty $_.PSPath }) | Select-Object @{n = "Index"; e = { (++$Global:index) } }, @{n = "DistributionName"; e = { $_.DistributionName; ($Global:name += $_.DistributionName)>$null } }, @{n = "Path"; e = { $_.BasePath.Replace("\\?\", "").Replace("\RootFS", ""); ($Global:path += $_.BasePath.Replace("\\?\", "").Replace("\RootFS", ""))>$null } }) | Out-String
		Write-Host "----------------------------------------------------------------------------------------------------------------"
		$m = Read-Host "[N]ew install distro, [I]mport distro, [E]xport distro, Reset [P]assword, [R]emove distro or [Q]uit"
		switch ($m) {
			'N' {
				install
			} 
			'R' {
				remove
			}
			'P' {
				resetpasswd
			}
			'I' {
				import
			}
			'E' {
				export
			}
			'Q' {
				Write-Host "Exiting..."
				Start-Sleep -s 2
				exit
			}
		}
		pause
	}
	until ($m -eq 'q') 
}

function install {
	$newline = "`r`n"
	$SetupFolder = "$env:LOCALAPPDATA/Programs"
	$TermIconPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState"
	$TermSettingsPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

	Write-Host "------------------------------------------------------------"
	$DistroName = Read-Host -Prompt 'Input your distro name'
	$DistroPath = "$SetupFolder/$DistroName"
	$DistroIcon = Read-Host -Prompt 'Input your distro icon name or drag-drop icon here'
	$DistroIconFilename=$DistroIcon
	if ($DistroIcon.Length -gt 0 -and (Test-Path $DistroIcon)) {
		$DistroIconFilename = Split-Path $DistroIcon -leaf
		Copy-Item -Path $DistroIcon -Destination $TermIconPath
	}
	$PackageManName = Read-Host -Prompt 'Input your package manager name (example: fedora->dnf, rhel->yum, arch->pacman, ubuntu->apt...)'
	$DistroURL = Read-Host -Prompt 'Input your distro url (tar.xz link) or path of local file (alternatively drag-drop the file here)'
	$DistroFilename = $DistroName + ".tar.xz"

	Write-Host "------------------------------------------------------------"
	Write-Host -NoNewLine "Checking existing WSL installations..."
	$result = (wsl --list)
	$arr = @()
	$result.ForEach( { if (($_ -ne "Windows Subsystem for Linux Distributions:") -and ($_ -ne "")) { $arr += ($_.replace(" (Default)", "")) } })
	foreach ($item in $arr) {
		if ($item -like "$DistroName") {
			Write-Host "ERROR there is existing WSL distro with name: "$DistroName
			Write-Host "Returning to main menu..."
			Start-Sleep -s 2
			mainfn
		}
	}

	Write-Host -NoNewLine "`rChecking existing WSL installations...		Done."
	Write-Host
	
	if (Test-Path $DistroPath) {
		Remove-Item "$DistroPath" -Filter * -Recurse -ErrorAction Ignore >$null
	}
	else {
		Write-Host "Created $DistroPath directory"
		New-Item -ItemType directory -Path "$DistroPath" >$null
	}

	Write-Host "Downloading 7Zip4Powershell for extract xz archive..."
	Save-Module -Name 7Zip4Powershell -Path $DistroPath
	$ver = Get-ChildItem -Path $DistroPath/7Zip4Powershell/ -Name
	Import-Module $DistroPath/7Zip4Powershell/$ver/7Zip4PowerShell.psd1

	if ($DistroURL -like "http*") {
		Write-Host "Downloading $DistroName Image"
		Import-Module BitsTransfer
		Start-BitsTransfer -Source "$DistroURL" -Destination "$DistroPath/$DistroName.tar.xz"
	}
	else {
		if(Test-Path $DistroURL){
			Write-Host "Copying $DistroName Image"
			$DistroFilename = Split-Path $DistroURL -leaf
			Copy-Item -Path $DistroURL -Destination "$DistroPath/"
			}
	}

	Write-Host "Extracting..."
	Expand-7Zip $DistroPath/$DistroFileName $DistroPath/

	$DistroFileName = $DistroFileName.Replace(".xz", "")
	$DistroFileName = $DistroFileName.Replace(".gz", "")
	Write-Host "Installing $DistroName..."
	wsl.exe --import $DistroName $DistroPath/RootFS $DistroPath/$DistroFileName

	Write-Host "------------------------------------------------------------"
	Write-Host "Opening $DistroName as root user"
	
	if ($PackageManName -like "*pacman*") {
		wsl -d $DistroName $PackageManName -Syu --noconfirm
		wsl -d $DistroName $PackageManName -S --noconfirm wget curl sudo ncurses passwd findutils
	}
	else {
		wsl -d $DistroName $PackageManName update -y
		wsl -d $DistroName $PackageManName -y install wget curl sudo ncurses passwd findutils
	}

	Write-Host "------------------------------------------------------------"
	$username = Read-Host -Prompt 'Please enter your username'
	wsl -d $DistroName useradd -G wheel $username
	wsl -d $DistroName passwd $username
	$uid = wsl -d $DistroName -u $username id -u

	Write-Host "------------------------------------------------------------"
	Write-Host "Registering to Windows Terminal..."
	Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq $DistroName  | Set-ItemProperty -Name DefaultUid -Value $uid

	if ($DistroIconFilename.Length -gt 3) {
		$old = '"name": "' + $DistroName + '",'
		$new = '"name": "' + $DistroName + '",' + $newline + '			"icon": "ms-appdata:///roaming/' + $DistroIconFilename + '",' + $newline
		((Get-Content "$TermSettingsPath\settings.json") -replace $old, $new) | set-content -path "$TermSettingsPath\settings.json"
	}
	Write-Host "Returning to main menu..."
	Start-Sleep -s 2
	mainfn
}

function remove {
	$idx = Read-Host "Select Index number to remove distro(0 - $index)"
	if (($idx -ge 0) -and ($idx -le $index)) {
		$wstr = "Removing "+$Global:name[$idx]+", continue?"
		$wstr | Write-Warning -WarningAction Inquire
		wsl --unregister $Global:name[$idx]
		if (Test-Path $Global:path[$idx]) { 
			Remove-Item $Global:path[$idx] -Filter * -Recurse -ErrorAction Ignore >$null
			Write-Host $Global:path[$idx]" removed!"
		}
	}
	Write-Host "Returning to main menu..."
	Start-Sleep -s 2
	mainfn

}
function export {
	$idx = Read-Host "Select Index number to export distro(0 - $index)"
	if (($idx -ge 0) -and ($idx -le $index)) {

		Add-Type -AssemblyName PresentationFramework

		$dlg = New-Object 'Microsoft.Win32.SaveFileDialog'
		$dlg.FileName = $Global:name[$idx] # Default file name
		$dlg.DefaultExt = ".tar" # Default file extension
		$dlg.Filter = "tar archives (.tar)|*.tar" # Filter files by extension

		# Show save file dialog box
		$result = $dlg.ShowDialog()

		# Process save file dialog box results
		if ($result) {
		# Save document
		$filename = $dlg.FileName;
		
		wsl.exe --export $Global:name[$idx] $filename
		Write-Host $Global:name[$idx]" exported to: "$filename
		}
	}
	Write-Host "Returning to main menu..."
	Start-Sleep -s 2
	mainfn
}

function import {
	$newline = "`r`n"
	$SetupFolder = "$env:LOCALAPPDATA/Programs"
	$TermIconPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState"
	$TermSettingsPath = "$env:LOCALAPPDATA\packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
	$distname = Read-Host "Input the distro name to import"
	$distfile = Read-Host "Input the path of local file (alternatively drag-drop the file here) to import"
	$disticon = Read-Host -Prompt 'Input your distro icon name or drag-drop icon here'
	$disticonfilename = $disticon
	if ($disticon.Length -gt 0 -and (Test-Path $disticon)) {
		$disticonfilename = Split-Path $disticon -leaf
		Copy-Item -Path $disticon -Destination $TermIconPath
	}
	if ($distname.Length -gt 0 -and (Test-Path $distfile)) {
		$result = (wsl --list)
		$arr = @()
		$result.ForEach( { if (($_ -ne "Windows Subsystem for Linux Distributions:") -and ($_ -ne "")) { $arr += ($_.replace(" (Default)", "")) } })
		foreach ($item in $arr) {
			if ($item -like "$distname") {
				Write-Host "ERROR there is existing WSL distro with name: "$distname
				Write-Host "Returning to main menu..."
				Start-Sleep -s 2
				mainfn
			}
		}
		wsl --import $distname $SetupFolder/$distname $distfile
		Write-Host $distname" imported!"
		
		$users=wsl -d $distname -u root getent passwd '{1000..60000}'
		Write-Host
		Write-Host "Users in "$distname
		ForEach-Object { $users } | Select-Object @{n = "Index"; e = { ($users.indexof($_)) } }, @{n = "Username"; e = { ($_.split(':')[0]) } }, @{n = "Userid"; e = { ($_.split(':')[2]) } } | Out-String
		
		Write-Host "------------------------------------------------------------"
		$idx = Read-Host 'Input index of user to set default (0 - '($users.Length-1)')'
		
		if (($idx -ge 0) -and ($idx -le $index)) {
			$uid=($users[$idx].split(':')[2])
			Write-Host "Setting default user to"($users[$idx].split(':')[0])
			Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq $distname  | Set-ItemProperty -Name DefaultUid -Value $uid
			
			if ($disticonfilename.Length -gt 3) {
				$old = '"name": "' + $distname + '",'
				$new = '"name": "' + $distname + '",' + $newline + '			"icon": "ms-appdata:///roaming/' + $disticonfilename + '",' + $newline
				((Get-Content "$TermSettingsPath\settings.json") -replace $old, $new) | set-content -path "$TermSettingsPath\settings.json"
			}
		}
		#0..($users.Length-1)|%{$users[$_]=$users[$_].split(':')[0]}
		
	}
	Write-Host "Returning to main menu..."
	Start-Sleep -s 2
	mainfn
}

function resetpasswd {
	$idx = Read-Host "Select Index number to reset distro password (0 - $index)"
	if (($idx -ge 0) -and ($idx -le $index)) {
		$usr = Read-Host "Input the username to reset password"
		$wstr = "Reset password for "+$usr+" at "+$Global:name[$idx]+", continue?"
		$wstr | Write-Warning -WarningAction Inquire
		wsl -d $Global:name[$idx] --user root passwd $usr
	}
	Write-Host "Returning to main menu..."
	Start-Sleep -s 2
	mainfn
}

$index = -1;
$name = @()
$path = @()

mainfn
Write-Host "Exiting..."
Start-Sleep -s 2