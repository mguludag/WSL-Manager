# if this file cannot run by execution policy, copy this line below and paste into powershell window then drag-drop this script into window and it will run
Set-ExecutionPolicy RemoteSigned -scope Process -Force

function mainfn {
    do {
        Clear-Host
        Write-Host "WSL Distro Manager"
        Write-Host "------------------------------------------------------------"

        $Global:index = -1
        $Global:name = @()
        $Global:path = @()
		
        Write-Host "Installed WSL Distributions"
        Write-Host "------------------------------------------------------------"
		((Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object { Get-ItemProperty $_.PSPath }) | 
        Select-Object @{n = "Index"; e = { (++$Global:index) } }, 
        @{n = "DistributionName"; e = { $_.DistributionName; ($Global:name += $_.DistributionName)>$null } }, 
        @{n = "Version"; e = { $_.Version; ($Global:version += $_.Version)>$null } }, 
        @{n = "Size"; e = { [math]::Round(((Get-ChildItem ($_.BasePath.Replace("\\?\", "").Replace("\RootFS", "") + "\ext4.vhdx")).Length / 1GB), 2).ToString() + "GB"; 
		($Global:size += ((Get-ChildItem ($_.BasePath.Replace("\\?\", "").Replace("\RootFS", "") + "\ext4.vhdx")).Length / 1GB))>$null } 
        }, 
        @{n = "Path"; e = { $_.BasePath.Replace("\\?\", "").Replace("\RootFS", ""); ($Global:path += $_.BasePath.Replace("\\?\", "").Replace("\RootFS", ""))>$null } }) | Out-String
        Write-Host "----------------------------------------------------------------------------------------------------------------"
        if($Global:args[0].Length -gt 0){
            $m = $Global:args[0]
            $Global:args = @()
        }
        else {
            $m = Read-Host "[N]ew install distro, [I]mport distro, [E]xport distro, [C]hange version, [S]hrink vhdx, Reset [P]assword, [R]emove distro or [Q]uit"
        }
        
        
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
            'C' {
                change_version
            }
            'S' {
                shrink
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
    $DistroIconFilename = $DistroIcon
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
        if (Test-Path $DistroURL) {
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
    Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | 
    Where-Object -Property DistributionName -eq $DistroName  | Set-ItemProperty -Name DefaultUid -Value $uid

    if ($DistroIconFilename.Length -gt 3) {
        $old = '"name": "' + $DistroName + '",'
        $new = '"name": "' + $DistroName + '",' + $newline + '"icon": "ms-appdata:///roaming/' + $DistroIconFilename + '",' + $newline
		((Get-Content "$TermSettingsPath\settings.json") -replace $old, $new) | set-content -path "$TermSettingsPath\settings.json"
    }
    Write-Host "Returning to main menu..."
    Start-Sleep -s 2
    mainfn
}

function remove {
    $idx = Read-Host "Select Index number to remove distro(0 - $Global:index)"
    if (($idx -ge 0) -and ($idx -le $Global:index)) {
        $wstr = "Removing " + $Global:name[$idx] + ", continue?"
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
function change_version {
    $idx = Read-Host "Select Index number to change distro wsl version(0 - $Global:index)"
    if (($idx -ge 0) -and ($idx -le $Global:index)) {
        $wstr = "Change " + $Global:name[$idx] + " wsl version to" + (3 - $Global:version[$idx]) + ", continue?"
        $wstr | Write-Warning -WarningAction Inquire
        wsl --shutdown
        wsl --set-version $Global:name[$idx] (3 - $Global:version[$idx])
    }
    Write-Host "Returning to main menu..."
    Start-Sleep -s 2
    mainfn

}
function shrink {
    $idx = Read-Host "Select Index number to shrink distro vhdx(0 - $Global:index)"
    if (($idx -ge 0) -and ($idx -le $Global:index)) {
        $wstr = "Shrink " + $Global:name[$idx] + " wsl disk, continue?"
        $wstr | Write-Warning -WarningAction Inquire
        wsl -d $Global:name[$idx] -u root  -- fstrim /
        Start-Sleep -s 2
        wsl --shutdown
        $vdisk = $Global:path[$idx] + "\ext4.vhdx"
		
		$diskpartcmd = @"
select vdisk file=$vdisk
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@

$diskpartbat = @"
dıskpart /s $pwd/diskpartcmd.txt
exit
"@
		
		Out-File -FilePath $pwd/diskpartcmd.txt -InputObject $diskpartcmd
		Out-File -FilePath $pwd/diskpartbat.bat -InputObject $diskpartbat
		Start-Sleep -s 2
		if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
			$proc = Start-Process -FilePath 'cmd' -ArgumentList ('`/K', "$pwd/diskpartbat.bat" | % { $_ }) -Verb RunAs -Passthru
			do {start-sleep -Milliseconds 500}
			until ($proc.HasExited)
		}
		Start-Sleep -s 2
		Remove-Item "$pwd/diskpartcmd.txt"
		Remove-Item "$pwd/diskpartbat.bat"

    }
    Write-Host "Returning to main menu..."
    Start-Sleep -s 2
    mainfn

}
function export {
    $idx = Read-Host "Select Index number to export distro(0 - $Global:index)"
    if (($idx -ge 0) -and ($idx -le $Global:index)) {

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
		
        $users = wsl -d $distname -u root getent passwd '{1000..60000}'
        Write-Host
        Write-Host "Users in "$distname
        ForEach-Object { $users } | Select-Object @{n = "Index"; e = { ($users.indexof($_)) } }, 
        @{n = "Username"; e = { ($_.split(':')[0]) } }, @{n = "Userid"; e = { ($_.split(':')[2]) } } | Out-String
		
        Write-Host "------------------------------------------------------------"
        $idx = Read-Host 'Input index of user to set default (0 - '($users.Length - 1)')'
		
        if (($idx -ge 0) -and ($idx -le $index)) {
            $uid = ($users[$idx].split(':')[2])
            Write-Host "Setting default user to"($users[$idx].split(':')[0])
            Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | 
            Where-Object -Property DistributionName -eq $distname  | Set-ItemProperty -Name DefaultUid -Value $uid
			
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
    $idx = Read-Host "Select Index number to reset distro password (0 - $Global:index)"
    if (($idx -ge 0) -and ($idx -le $Global:index)) {
        $usr = Read-Host "Input the username to reset password"
        $wstr = "Reset password for " + $usr + " at " + $Global:name[$idx] + ", continue?"
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
$version = @()
$size = @()

mainfn
Write-Host "Exiting..."
Start-Sleep -s 2
# SIG # Begin signature block
# MIIbwAYJKoZIhvcNAQcCoIIbsTCCG60CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBfUWhzUsN2YlyG
# ZQtqBOYHiJIojwEX6wYNkMDbWqORD6CCFhEwggMGMIIB7qADAgECAhBaIcxeH1Zf
# iEJiKw2dexQUMA0GCSqGSIb3DQEBCwUAMBsxGTAXBgNVBAMMEEFUQSBBdXRoZW50
# aWNvZGUwHhcNMjIwNzA4MTExMDQ4WhcNMjMwNzA4MTEzMDQ4WjAbMRkwFwYDVQQD
# DBBBVEEgQXV0aGVudGljb2RlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEAwLXkPIi05Ijg6CsCsP96WDpP66X4K51ffcP/N8IMrEazbaMtQamfbbpRIiJt
# kp/tGlt8oHBEUPqZK304irX9yKgq3VLb9oHqHn5ObTcLtmO95H3mF3ylwPzBBFCz
# f/TFP1XwyYYp6WP71aaP1DEcM0JzTVLCW3hKb+AkLDSe6PRPG8xjhMP3S0d1dh+O
# TDwnpbTW73prLb3eCWQ618I6o1KmTA0VKE2VQVTaen3tBN3k1V0lJAa4QHjgxH8v
# iakxavMNYHkr0ePeTLDZ1bHuoV+rw2VnmrK1Hn5qubjhdKDlJuJobSnHloGy2lVD
# Zn1Ln9Gfu0hFYe1SkHB/vZW7KQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYD
# VR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFIdyoB6jE6kWeMJI6Ut6n6xe1hQN
# MA0GCSqGSIb3DQEBCwUAA4IBAQAsfKFHvkmar2jhdyvWbD7d9FYZp81phNi2nZu7
# HWmATFg/PuKxwcwjuQdIX7v8mltecE85VXCy8p/eaXsRVJlDaxdLIC9URzBV/dW9
# mYk6xd5CsJzv/oZ5owZImI9Ah3kw9FSxLuOG2NKYd4J3uzKMYLBRTK1vzR1IgxTM
# XbiBuB4nqblvSAQuklRAK0UR/CPxB947EIhHgt5BbVm2wwtAkpcDP0BkYY+IWTiO
# tufg3eGRg8OT0A15cWsZ++fCAAt6H5xyYJKgCGuU+o0zOcZ+S5RR3gUshYosl5bG
# mFZMgumrtBHgqcET0zwRZxikXkMdgiIkMViqp2yRdpWpraWpMIIFjTCCBHWgAwIB
# AgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIw
# ODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Y
# q3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lX
# FllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxe
# TsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbu
# yntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I
# 9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmg
# Z92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse
# 5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKy
# Ebe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwh
# HbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/
# Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwID
# AQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM
# 3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYD
# VR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+
# MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3Vy
# ZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUA
# A4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSI
# d229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7U
# z9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxA
# GTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAID
# yyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW
# /VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0o
# ZipeWzANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhE
# aWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIy
# MjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# OzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGlt
# ZVN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1
# BkmzwT1ySVFVxyUDxPKRN6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3z
# nIkLf50fng8zH1ATCyZzlm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZ
# Kz5C3GeO6lE98NZW1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald6
# 8Dd5n12sy+iEZLRS8nZH92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zk
# psUdzTYNXNXmG6jBZHRAp8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYn
# LvWHpo9OdhVVJnCYJn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIq
# x5K/oN7jPqJz+ucfWmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOd
# OqPVA+C/8KI8ykLcGEh/FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJ
# TYsg0ixXNXkrqPNFYLwjjVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJR
# k8mMDDtbiiKowSYI+RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEo
# AA6EVO7O6V3IXjASvUaetdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8G
# A1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjAT
# BgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYD
# VR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9
# bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0T
# zzBTzr8Y+8dQXeJLKftwig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYS
# lm/EUExiHQwIgqgWvalWzxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaq
# T5Fmniye4Iqs5f2MvGQmh2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl
# 2szwcqMj+sAngkSumScbqyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1y
# r8THwcFqcdnGE4AJxLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05
# et3/JWOZJyw9P2un8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6um
# AU+9Pzt4rUyt+8SVe+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSwe
# Jywm228Vex4Ziza4k9Tm8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr
# 7ZVBtzrVFZgxtGIJDwq9gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYC
# JtnwZXZCpimHCUcr5n8apIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzga
# oSv27dZ8/DCCBsAwggSooAMCAQICEAxNaXJLlPo8Kko9KQeAPVowDQYJKoZIhvcN
# AQELBQAwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTsw
# OQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVT
# dGFtcGluZyBDQTAeFw0yMjA5MjEwMDAwMDBaFw0zMzExMjEyMzU5NTlaMEYxCzAJ
# BgNVBAYTAlVTMREwDwYDVQQKEwhEaWdpQ2VydDEkMCIGA1UEAxMbRGlnaUNlcnQg
# VGltZXN0YW1wIDIwMjIgLSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
# AgEAz+ylJjrGqfJru43BDZrboegUhXQzGias0BxVHh42bbySVQxh9J0Jdz0Vlggv
# a2Sk/QaDFteRkjgcMQKW+3KxlzpVrzPsYYrppijbkGNcvYlT4DotjIdCriak5Lt4
# eLl6FuFWxsC6ZFO7KhbnUEi7iGkMiMbxvuAvfTuxylONQIMe58tySSgeTIAehVbn
# he3yYbyqOgd99qtu5Wbd4lz1L+2N1E2VhGjjgMtqedHSEJFGKes+JvK0jM1MuWbI
# u6pQOA3ljJRdGVq/9XtAbm8WqJqclUeGhXk+DF5mjBoKJL6cqtKctvdPbnjEKD+j
# HA9QBje6CNk1prUe2nhYHTno+EyREJZ+TeHdwq2lfvgtGx/sK0YYoxn2Off1wU9x
# LokDEaJLu5i/+k/kezbvBkTkVf826uV8MefzwlLE5hZ7Wn6lJXPbwGqZIS1j5Vn1
# TS+QHye30qsU5Thmh1EIa/tTQznQZPpWz+D0CuYUbWR4u5j9lMNzIfMvwi4g14Gs
# 0/EH1OG92V1LbjGUKYvmQaRllMBY5eUuKZCmt2Fk+tkgbBhRYLqmgQ8JJVPxvzvp
# qwcOagc5YhnJ1oV/E9mNec9ixezhe7nMZxMHmsF47caIyLBuMnnHC1mDjcbu9Sx8
# e47LZInxscS451NeX1XSfRkpWQNO+l3qRXMchH7XzuLUOncCAwEAAaOCAYswggGH
# MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSME
# GDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQUYore0GH8jzEU7ZcL
# zT0qlBTfUpwwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NB
# LmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGlu
# Z0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAVaoqGvNG83hXNzD8deNP1oUj8fz5
# lTmbJeb3coqYw3fUZPwV+zbCSVEseIhjVQlGOQD8adTKmyn7oz/AyQCbEx2wmInc
# ePLNfIXNU52vYuJhZqMUKkWHSphCK1D8G7WeCDAJ+uQt1wmJefkJ5ojOfRu4aqKb
# wVNgCeijuJ3XrR8cuOyYQfD2DoD75P/fnRCn6wC6X0qPGjpStOq/CUkVNTZZmg9U
# 0rIbf35eCa12VIp0bcrSBWcrduv/mLImlTgZiEQU5QpZomvnIj5EIdI/HMCb7XxI
# stiSDJFPPGaUr10CU+ue4p7k0x+GAWScAMLpWnR1DT3heYi/HAGXyRkjgNc2Wl+W
# FrFjDMZGQDvOXTXUWT5Dmhiuw8nLw/ubE19qtcfg8wXDWd8nYiveQclTuf80EGf2
# JjKYe/5cQpSBlIKdrAqLxksVStOYkEVgM4DgI974A6T2RUflzrgDQkfoQTZxd639
# ouiXdE4u2h4djFrIHprVwvDGIqhPm73YHJpRxC+a9l+nJ5e6li6FV8Bg53hWf2rv
# wpWaSxECyIKcyRoFfLpxtU56mWz06J7UWpjIn7+NuxhcQ/XQKujiYu54BNu90ftb
# CqhwfvCXhHjjCANdRyxjqCU4lwHSPzra5eX25pvcfizM/xdMTQCi2NYBDriL7ubg
# clWJLCcZYfZ3AYwxggUFMIIFAQIBATAvMBsxGTAXBgNVBAMMEEFUQSBBdXRoZW50
# aWNvZGUCEFohzF4fVl+IQmIrDZ17FBQwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYB
# BAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgdyNp
# hcPbgZ1THUYPofKxo6w0/1+XYeopEwS8c2GZh1AwDQYJKoZIhvcNAQEBBQAEggEA
# cmYmA9w7CbUDsCAK/Jdf33OXxBNsQ0FCvAa1iAWSg0irRdSjM27ihbL2BQeOO098
# vPMYMoKRpr/ysNVDvMLsRY/J5WMFbjOKL4AAVWJXMTFwAznQJFS6wRsL8wlw3Xg0
# drki1CNpCVvSMTjw48usxPQBNT/8VHQ+/aMXT6OSujwCjnJNB7h8oS03M2V8aj5I
# lnBpssb5s9VcMYecH7NWPIK84DXTAfG4H0OAUD4zoLYq0rjp4+DxRZhICzIiSEzh
# DQ0ira9NxMA5weK682q6hwjQkNblbg94MDHytwunM+8iwA4jeJUaIP2SmsRwJahy
# UbIW8nDwVp+DWC093s4KhqGCAyAwggMcBgkqhkiG9w0BCQYxggMNMIIDCQIBATB3
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBp
# bmcgQ0ECEAxNaXJLlPo8Kko9KQeAPVowDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG
# 9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMzA1MTMxOTE2NDJa
# MC8GCSqGSIb3DQEJBDEiBCDviAXYtZW8k2r/Y2kyAdav6GDMY1A33JcYWUDsuAoR
# mjANBgkqhkiG9w0BAQEFAASCAgCfgWHFOnsUtWknSmtytCZMDJk/dab3Hc6vrq1a
# ibaqGW6bCiLXNhWi+bc0hwuLqJYr1WhiBQRIp8uUrvwVAogukn0NRAGJXhpcVE44
# LGiVIjfMe+1r08+dQ5fK9hTkWev/5pLWggty42g0fcRqxE3hglRwkdiPbb08GThe
# t7R3aMYZVg7Czu3smZgMMKb9vKFbmKH2dGL7GA8u4ONVQCHyjtJtI1CB2dmGNigO
# JNM1D+yXL94g3p4zX1sx0to72W6FW92XN2Y8Q/yppfjVdYHkonaI65h+9LaG6YSy
# H0R4wMh853E2LNhG1il7Td3llvRs5dhQ57bEcLk8mgOQibmEdyd6PvdJ+zAwlzBL
# kDVs1lhsK9xweXN885L59oDD5dRlvlh6vbO3JexAmGRwJjaLj5JK0s94hTTM/hnY
# HgDWlXP7jvqWE6TZBqmF2Z6YFa/9cvKatx4gKevYrlEd+hd7ZG2isunEUdK7TKpV
# 2UBhBHOtZydnY3zdXiNiVSxhRxe/8OQKtkaQuz5FvZTJ/KUmtZddl2d9xqpLJSof
# YCmkMxmvhRqyA+6NwqUtlFP0iGJLkEOA+h6mkQ/ke1S74QhpLLhm7dgu5Q/udwVD
# 7cN4+65YmnuLb04c9fWJRZFEy01m1L6zzXIbO8gjMieaygoStluMBGW+Ek+33YyL
# SZiVFQ==
# SIG # End signature block
