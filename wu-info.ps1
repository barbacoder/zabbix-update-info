
<#


Parameters
 -createScheduledTask
	 should be run as Administrator! This will create a scheduled task to clear and create the windows update info cache file.
 -clearcache
	clear cache, no output
 -writecache
	write cache (possible overwrite), no output
 -refreshcache
	clear+write, no output

 -readcache : gives error json when no cache is present, can be ommited, usefull in combination with any of the clear|write|refreshcache options
 
 -item <item name> any of the available json items gives value of item
 -item days-elapsed 
 -item updates-waiting
 -item timestamp
 
 
 Zabbix UserParams:
 #UserParameter=windows.update.stats.create-scheduled-task,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -createScheduledTask
UserParameter=windows.update.stats.json,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -readcache
UserParameter=windows.update.stats.json.refresh,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -refreshcache
UserParameter=windows.update.stats.days-elapsed,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -readcache -item days-elapsed
UserParameter=windows.update.stats.updates-waiting,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -readcache -item updates-waiting
UserParameter=windows.update.stats.timestamp,powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\util\zabbix\scripts\wu-info.ps1" -readcache -item timestamp

 
 #>
 
param(
  [switch]$refreshcache = $false,
  [switch]$readcache = $false,
  [switch]$clearcache = $false,
  [switch]$writecache = $false,
  [switch]$createScheduledTask = $false,
  [string]$item = ""
)


$WUInfoCacheFile = "C:\util\zabbix\scripts\wu-info.json"
$err_no_wuinfo_cache = '{"windows-update-info": {"error": "no windows updates stats cache file available"}]'



function createScheduledtask (){
#	# Create scheduled task
	$taskname = "WU-Stats Refresh Cache"
	$trigger= New-ScheduledTaskTrigger -At 01:00 -Daily
	$user= "SYSTEM"
	$action= New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy bypass -File C:\util\zabbix\scripts\wu-info.ps1 -refreshcache"

	Register-ScheduledTask -TaskName $taskname -Trigger $trigger -User $user -Action $action -RunLevel Highest -Force
}



# https://sbcode.net/zabbix/powershell-windows-updates/

function Get-DaysSinceLastUpdate {
	$date = Get-Date
	$diff = (Get-HotFix | Sort-Object -Property InstalledOn)[-1] | Select-Object InstalledOn
	$diff3 = New-TimeSpan -Start $diff.InstalledOn -end $date
	return $diff3.days
}

function Get-UninstalledUpdatesCount {
	#Attribution: https://sbcode.net/zabbix/powershell-windows-updates/
	[Int]$Count = 0
	$Searcher = new-object -com "Microsoft.Update.Searcher"
	$Searcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0").Updates | ForEach-Object { $Count++ }
	return $Count
}



function Get-WindowsUpdatesStats {
#	Write-Host "*** Get-WindowsUpdatesStats"
	$result= @()
	$result = [ordered]@{
				"days-elapsed"= Get-DaysSinceLastUpdate
				"updates-waiting"= Get-UninstalledUpdatesCount
				"timestamp"= (Get-Date).toString("yyyy/MM/dd HH:mm:ss")			
	}
	return $result
 }



function Get-UpdateInfo($update) {
#	Write-Host "*** Get-UpdateInfo" + $update.Title
	$result=@()
	$result = [ordered]@{
		$update.Title= @{		  
				installed = $update.IsInstalled
				isdownloaded = $update.IsDownloaded
		}
    }
	return $result	
}

 function Get-UpdatesList {
#	Write-Host "*** Get-UpdatesList"
	$result=@()
	$Searcher = new-object -com "Microsoft.Update.Searcher"
	$updateList = $Searcher.Search("IsAssigned=1 and IsHidden=0").Updates 
	$updateList | ForEach {
		$result += Get-UpdateInfo($_)
	}

	$output= @()
	$output = [ordered]@{
				"windows-update-list"= @($result)
	}
	return $output
 }




function Get-UpdateInfoJSON {
	# create ordered list of results
	$output=@()
	$stats = Get-WindowsUpdatesStats
	$list = Get-UpdatesList
	
	@{"windows-update-info"=@($stats; $list)} | ConvertTo-Json -Depth 6 -Compress
}


function outputItem($output) {
	$data = $output | ConvertFrom-Json
	$data2 = $data."windows-update-info"
	$output = $data2.$item
	$output
}

function main {

	$output=""
	$cacheParam=$false

	if ($createScheduledTask) {
		createScheduledTask
		break
	}

	$cacheParam=$false

	if ($refreshcache) {
		$clearcache = $true
		$writecache = $true
	}
		
	
	if ($clearcache) {
		$cacheParam=$true
		try {
			Remove-Item -Path $WUInfoCacheFile -ErrorAction SilentlyContinue
		} 
		catch { 
			break 
		}

		if ($readcache) {
			# cache will be read, so create new one!
			$writecache = $true
		}
	}

	if ($writecache) {
		$cacheParam=$true
		$output = UpdateInfoJSON
		$output | Set-Content -Path $WUInfoCacheFile
	}


	if (!$cacheParam) {
		#no cache control params processed, process as readcache"
		$readCache = $true
	}
	
	if ($readcache)  {
		try {
			$output = Get-Content -Path $WUInfoCacheFile -ErrorAction Stop
		}
		catch {
			if ($cacheParam) {
				#Cache control params processed, so cache read error is final, give error json if no specific item is asked
				if (!$item){
					$err_no_wuinfo_cache
				}
				break
			} else {
				# Cache read error, so creating new info"
				$output = UpdateInfoJSON
				$output | Set-Content -Path $WUInfoCacheFile
			}
		}
		
		if ($item) { 
			outputItem $output
			break
		} else {
			$output
		}
		break
	}
	
}	



main