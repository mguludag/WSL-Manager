function mainfn {
	do
	{
		Clear-Host
		$m = Read-Host "[I]nstall, [S]how WSL distributions or [Q]uit"
		switch ($m)
		{
			'I' {
				  install
			} 
			'S' {
				manage
			}
			'Q' {
				Start-Sleep -s 2
				exit
			}
		}
		pause
	}
	until ($m -eq 'q') 
 }

function install {
	$newline = "`r`n`r`n"
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
	$installcmd = "-y install"
	$updatecmd = "update -y"



	Write-Output ""
	Write-Output "Checking existing WSL installations..."
	$ex=wsl --list >$null

	if($ex -like "$DistroName (Default)" -or "$DistroName*"){
		Write-Output ""
		Write-Output "Unregistering same name WSL installations..."
		wsl --unregister $DistroName >$null
	}

	if(Test-Path $DistroPath){
		Remove-Item "$DistroPath" -Filter * -Recurse -ErrorAction Ignore >$null
	}
	else{
		Write-Output ""
		Write-Output "Created $DistroPath directory"
		New-Item -ItemType directory -Path "$DistroPath" >$null
	}

	Write-Output ""
	Write-Output "Downloading 7Zip4Powershell for extract xz archive..."
	Save-Module -Name 7Zip4Powershell -Path $DistroPath
	$ver=Get-ChildItem -Path $DistroPath/7Zip4Powershell/ -Name
	Import-Module $DistroPath/7Zip4Powershell/$ver/7Zip4PowerShell.psd1

	if($DistroURL -like "http*"){
		Write-Output ""
		Write-Output "Downloading $DistroName Image"
		Import-Module BitsTransfer
		Start-BitsTransfer -Source "$DistroURL" -Destination "$DistroPath/$DistroName.tar.xz"
	}
	else{
	Write-Output ""
		Write-Output "Copying $DistroName Image"
		$DistroFilename = Split-Path $DistroURL -leaf
		Copy-Item -Path $DistroURL -Destination "$DistroPath/"
	}


	Write-Output ""
	Write-Output "Extracting..."
	Expand-7Zip $DistroPath/$DistroFileName $DistroPath/

	$DistroFileName=$DistroFileName.Replace(".xz","")
$DistroFileName=$DistroFileName.Replace(".gz","")
	Write-Output ""
	Write-Output "Installing $DistroName..."
	wsl.exe --import $DistroName $DistroPath/RootFS $DistroPath/$DistroFileName

	Write-Output ""
	Write-Output "Opening $DistroName as root user"
	Write-Output "$DistroName $PackageManName $updatecmd"
	
    if($PackageManName -like "*pacman*"){
		wsl -d $DistroName $PackageManName -Syu --noconfirm
		wsl -d $DistroName $PackageManName -S --noconfirm wget curl sudo ncurses passwd findutils
	}
	else{
		wsl -d $DistroName $PackageManName update -y
		wsl -d $DistroName $PackageManName -y install wget curl sudo ncurses passwd findutils
	}

	Write-Output ""
	$username = Read-Host -Prompt 'Please enter your username'
	wsl -d $DistroName useradd -G wheel $username
	wsl -d $DistroName passwd $username
	$uid = wsl -d $DistroName -u $username id -u

	Write-Output ""
	Write-Output "Registering to Windows Terminal..."
	Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq $DistroName  | Set-ItemProperty -Name DefaultUid -Value $uid

	if($DistroIconFilename.Length -gt 3){
	$old = '"name": "'+$DistroName+'",'
	$new = '"name": "'+$DistroName+'",'+$newline+'"icon": "ms-appdata:///roaming/'+$DistroIconFilename+'",'+$newline
	((Get-Content "$TermSettingsPath\settings.json") -replace $old, $new) | set-content -path "$TermSettingsPath\settings.json"
	}
	Write-Output "Done."
	Write-Output "Returning to main menu..."
	Start-Sleep -s 2
	mainfn
 }

function manage {
	Clear-Host
    $Global:index=-1
    $Global:name=@()
    $Global:path=@()
    
	Write-Host "Installed WSL Distributions"
	((Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object {Get-ItemProperty $_.PSPath}) | Select-Object @{n="Index";e={(++$Global:index)}}, @{n="DistributionName";e={$_.DistributionName;($Global:name+=$_.DistributionName)>$null}}, @{n="Path";e={$_.BasePath.Replace("\\?\","").Replace("\RootFS","");($Global:path+=$_.BasePath.Replace("\\?\","").Replace("\RootFS",""))>$null}}) | Out-String
	do
	{
		$showmenu = Read-Host "[R]emove, Go [B]ack or [Q]uit"
		switch ($showmenu)
		{
			'R' {
				$idx = Read-Host "Select Index number to remove distro(0 - $index)"
				if(($idx -ge 0) -and ($idx -le $index)){
                   wsl --unregister $Global:name[$idx]
				   if(Test-Path $Global:path[$idx]){ 
					   Remove-Item $Global:path[$idx] -Filter * -Recurse -ErrorAction Ignore >$null
					   Write-Host $Global:path[$idx]" removed!"
				   }
				}
				Write-Host "Returning to remove menu..."
				Start-Sleep -s 2
				manage
			} 
			'B' {
				mainfn
			} 
			'Q' {
				Start-Sleep -s 2
				exit
			}
		}
		pause
}
	until ($selection -eq 'q')
 }

 $index=-1;
 $name = @()
 $path = @()

 mainfn