<#
.SYNOPSIS
    Gets the Hardware/Software config of the targeted SQL server
	
.DESCRIPTION
    This script lists the Hardware and Software installed on the targeted SQL Server
    CPU, RAM, DISK, Installation and Backup folders, SQL Version, Edition, Patch Levels, Cluster/HA
	
.EXAMPLE
    01_Server_Appliance.ps1 localhost
	
.EXAMPLE
    01_Server_Appliance.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK
	https://github.com/gwalkey
	
#>
[CmdletBinding()]
Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance='localhost',

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,20)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,35)]
    [string]$mypass
)

# Import SQL Transscriptase Common Modules
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSMO.psm1"
LoadSQLSMO

Set-StrictMode -Version latest;

# Save Currnt Location
[string]$BaseFolder = (get-location).path

# Splash
Write-Host -f Yellow -b Black "01 - Server Appliance"
Write-Output "Server $SQLInstance"

# Get servername if parameter contains a SQL named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

# Server connection check
try
{
    $SQLCMD1 = "select serverproperty('productversion') as 'Version'"

    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"        
        $myver = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop| select -ExpandProperty Version
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
	$myver = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop | select -ExpandProperty Version
        $serverauth = "win"
    }

    if($myver -ne $null)
    {
        Write-Output ("SQL Version: {0}" -f $myver)
    }

}
catch
{
    Write-Host -f red "$SQLInstance appears offline."
    Set-Location $BaseFolder
	exit
}


# Create folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Appliance"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# New UP SMO Server Object
if ($serverauth -eq "win")
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}
else
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
        $srv.ConnectionContext.LoginSecure=$false
        $srv.ConnectionContext.set_Login($myuser)
        $srv.ConnectionContext.set_Password($mypass)    
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}


# Dump Initial Server info to output file
$fullFileName = $fullfolderPath+"\01_Server_Appliance.txt"
New-Item $fullFileName -type file -force | Out-Null
Add-Content -Value "Server Hardware and Software Capabilities for $SQLInstance `r`n" -Path $fullFileName -Encoding Ascii


# Get Server Uptime
if ($myver -like "9.0*")
{
    $mysql11 = 
    "
    SELECT DATEADD(ms,-sample_ms,GETDATE()) AS sqlserver_start_time FROM sys.dm_io_virtual_file_stats(1,1);
    "
}
else
{
    $mysql11 =
    "
    SELECT sqlserver_start_time FROM sys.dm_os_sys_info;
    "
}

# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults11 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql11
}
else
{
    $sqlresults11 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql11 -User $myuser -Password $mypass
}

if ($sqlresults11 -ne $null)
{
    "Engine Start Time: " + $sqlresults11.sqlserver_start_time+"`r`n" | out-file $fullFileName -Encoding ascii -Append  
}
else
{
    Write-Output "Cannot determine Server Uptime"
}



# Get SQL Engine Installation Date
$mysql12 = 
"
USE [master];

SELECT	MIN([crdate]) as 'column1'
FROM	[sys].[sysdatabases]
WHERE	[dbid] > 4 --not master, tempdb, model, msdb
;
"

# Connect correctly
if ($serverauth -eq "win")
{
    $sqlresults12 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql12
}
else
{
    $sqlresults12 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql12 -User $myuser -Password $mypass
}


if ($sqlresults12 -ne $null) {$myCreateDate = $sqlresults12.column1} else {$myCreateDate ='Unknown'}


# Get SQL Server Config Settings using SMO
$mystring =  "SQL Server Name: " +$srv.Name 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Server Create Date: " +$MyCreateDate
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Version: " +$srv.Version 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Edition: " +$srv.EngineEdition
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Build Number: " +$srv.BuildNumber
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product: " +$srv.Product
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product Level: " +$srv.ProductLevel
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Processors: " +$srv.Processors
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Max Physical Memory MB: " +$srv.PhysicalMemory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Physical Memory in Use MB: " +$srv.PhysicalMemoryUsageinKB
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB Path: " +$srv.MasterDBPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB LogPath: " +$srv.MasterDBLogPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Backup Directory: " +$srv.BackupDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Shared Dir: " +$srv.InstallSharedDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Data Dir: " +$srv.InstallDataDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Service Account: " +$srv.ServiceAccount
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Collation: " +$srv.Collation
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Security Model: " +$srv.LoginMode
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols - Named Pipes: " +$srv.NamedPipesEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols - TCPIP: " +$srv.TcpEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Browser Start Mode: " +$srv.BrowserStartMode
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols: " + ($srv.endpoints | select Parent, Name, Endpointtype, EndpointState, ProtocolType |format-table| out-string)
$mystring | out-file $fullFileName -Encoding ascii -Append


" " | out-file $fullFileName -Encoding ascii -Append

# Windows
$mystring =  "OS Version: " +$srv.OSVersion
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is Clustered: " +$srv.IsClustered
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is HADR: " +$srv.IsHadrEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Platform: " +$srv.Platform
$mystring | out-file $fullFileName -Encoding ascii -Append


# OS Info Via WMI
try
{

    $myWMI = Get-WmiObject –class Win32_OperatingSystem  -ComputerName $WinServer -ErrorAction SilentlyContinue | select Name, BuildNumber, BuildType, CurrentTimeZone, InstallDate, SystemDrive, SystemDevice, SystemDirectory

    Write-Output ("OS Host Name: {0}" -f $myWMI.Name ) | out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS BuildNumber: {0}" -f $myWMI.BuildNumber )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS Buildtype: {0}" -f $myWMI.BuildType )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS CurrentTimeZone: {0}" -f $myWMI.CurrentTimeZone)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS InstallDate: {0}" -f $myWMI.InstallDate)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDrive: {0}" -f $myWMI.SystemDrive)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDevice: {0}" -f $myWMI.SystemDevice)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDirectory:{0}" -f $myWMI.SystemDirectory)| out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting OS specs via WMI - WMI/firewall issue?"| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting OS specs via WMI - WMI/firewall issue?"
}

" " | out-file $fullFileName -Encoding ascii -Append

# ---------------
# Hardware
# ---------------
# Motherboard
# Turn off default Error Handler for WMI
try
{
    $myWMI = Get-WmiObject  -class Win32_Computersystem -ComputerName $WinServer -ErrorAction SilentlyContinue | select manufacturer
    Write-Output ("HW Manufacturer: {0}" -f $myWMI.Manufacturer ) | out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting Hardware specs via WMI - WMI/firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting Hardware specs via WMI - WMI/firewall issue? "
}


# Proc, CPUs, Cores
try
{

    $myWMI = Get-WmiObject –class Win32_processor -ComputerName $WinServer -ErrorAction SilentlyContinue | select Name, NumberOfLogicalProcessors, NumberOfCores
    Write-Output ("HW Processor: {0}" -f $myWMI.Name ) | out-file $fullFileName -Encoding ascii -Append
    Write-Output ("HW CPUs: {0}" -f $myWMI.NumberOfLogicalProcessors )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("HW Cores: {0}" -f $myWMI.NumberOfCores )| out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting CPU specs via WMI - WMI/Firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting CPU specs via WMI - WMI/Firewall issue? "
}

" " | out-file $fullFileName -Encoding ascii -Append


# Get PowerPlan
try
{
    $mystring41 = Get-CimInstance -N root\cimv2\power -Class win32_PowerPlan -ComputerName $WinServer -ErrorAction Stop | where-object {$_.isactive -eq $true}  | Select-Object -expandproperty ElementName
    
    if ($mystring41 -ne "High performance") 
    {
        Write-output ("PowerPlan: {0} *not optimal in a VM*" -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
        Write-output ("powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
    }
    else
    {
        Write-output ("PowerPlan: {0} " -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
    }
}
catch
{
    Write-Output("Error getting PowerPlan via WMI - WMI/Firewall issue? ")
    Write-Output("Error: {0}" -f $error[0])
    Write-Output( "Error getting PowerPlan via WMI - WMI/Firewall issue? ")| out-file $fullFileName -Encoding ascii -Append
    Write-Output("Error: {0}" -f $error[0])| out-file $fullFileName -Encoding ascii -Append
 
}


" " | out-file $fullFileName -Encoding ascii -Append


# Get PowerShell Version
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

if ($SQLInstance -eq 'localhost')
{
    $MyPSVersion = (Get-Host).Version
}
else
{
    if ($myuser.Length -gt 0 -and $mypass.Length -gt 0)
    {        
        $MyPSVersion = $null
    }
    else
    {
        $MyPSVersion = Invoke-Command -ComputerName $WinServer -ScriptBlock {$PSVersionTable.PSVersion}
    }
}
if ($MyPSVersion -ne $null)
{    
    $mystring =  "Powershell Version: " +$myPSVersion
}
else
{
    $mystring =  "Powershell Version: Unknown"
}
$mystring+"`r`n" | out-file $fullFileName -Encoding ascii -Append

$ErrorActionPreference = $old_ErrorActionPreference


# Get Network Adapter info
if ($SQLInstance -eq 'localhost')
{
    try
    {
        $Adapters = (Get-CIMInstance Win32_NetworkAdapterConfiguration -ComputerName . -ErrorAction stop).where({$PSItem.IPEnabled})
    }
    catch
    {
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"| out-file $fullFileName -Encoding ascii -Append
    }
}
else
{
    try
    {
        $Adapters = (Get-CIMInstance Win32_NetworkAdapterConfiguration -ComputerName $WinServer -ErrorAction stop).where({$PSItem.IPEnabled})
    }
    catch
    {
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"| out-file $fullFileName -Encoding ascii -Append
    }
}

foreach ($Adapter in $Adapters)
{
    # Get all Adapter Properties
    $AdapterSettings = [PSCustomObject]@{ 
    System = $Adapter.PSComputerName 
    Description = $Adapter.Description 
    IPAddress = $Adapter.IPAddress 
    SubnetMask = $Adapter.IPSubnet 
    DefaultGateway = $Adapter.DefaultIPGateway 
    DNSServers = $Adapter.DNSServerSearchOrder 
    DNSDomain = $Adapter.DNSDomain 
    DNSSuffix = $Adapter.DNSDomainSuffixSearchOrder 
    FullDNSREG = $Adapter.FullDNSRegistrationEnabled 
    WINSLMHOST = $Adapter.WINSEnableLMHostsLookup 
    WINSPRI = $Adapter.WINSPrimaryServer 
    WINSSEC = $Adapter.WINSSecondaryServer 
    DOMAINDNSREG = $Adapter.DomainDNSRegistrationEnabled 
    DNSEnabledWINS = $Adapter.DNSEnabledForWINSResolution 
    TCPNETBIOSOPTION = $Adapter.TcpipNetbiosOptions 
    IsDHCPEnabled = $Adapter.DHCPEnabled 
    AdapterName = $Adapter.Servicename
    MACAddress = $Adapter.MACAddress 
    } 

    $mystring ="Network Adapter[" +[array]::IndexOf($Adapters,$Adapter)+"]`r`n"
    $mystring+=  "Name: "+ $AdapterSettings.AdapterName+"`r`n"
    $index = 0
    foreach ( $Address in $AdapterSettings.IPAddress)
    {
        $mystring+= "Address["+[array]::IndexOf($AdapterSettings.IPAddress,$Address)+ "]: "+$Address+"`r`n"
    }

    foreach ( $subnet in $AdapterSettings.SubnetMask)
    {
        $mystring+= "Subnet["+[array]::IndexOf($AdapterSettings.SubnetMask,$subnet)+ "]: "+$Subnet+"`r`n"
    }
    
    $mystring+= "Gateway: {0}" -f $AdapterSettings.DefaultGateway+"`r`n"
    $mystring+="Description: {0}" -f $AdapterSettings.Description+"`r`n"
    $mystring+="DNS Name: {0}" -f $AdapterSettings.DNSServers
    $mystring+="`r`n" 
    $mystring | out-file $fullFileName -Encoding ascii -Append
}

# Section Footer
"`r`nSQL Build reference: http://sqlserverbuilds.blogspot.com/ " | out-file $fullFileName -Encoding ascii -Append
"`r`nSQL Build reference: http://sqlserverupdates.com/ " | out-file $fullFileName -Encoding ascii -Append
"`r`nMore Detailed Diagnostic Queries here:`r`nhttp://www.sqlskills.com/blogs/glenn/sql-server-diagnostic-information-queries-for-september-2015" | out-file $fullFileName -Encoding ascii -Append


# Get Loaded DLLs
$mysql15 = "select * from sys.dm_os_loaded_modules order by description"


# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults15 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql15
}
else
{
	$sqlresults15 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql15 -User $myuser -Password $mypass
}

# HTML CSS
$head = "<style type='text/css'>"
$head+="
table
    {
        Margin: 0px 0px 0px 4px;
        Border: 1px solid rgb(190, 190, 190);
        Font-Family: Tahoma;
        Font-Size: 9pt;
        Background-Color: rgb(252, 252, 252);
    }
tr:hover td
    {
        Background-Color: rgb(150, 150, 220);
        Color: rgb(255, 255, 255);
    }
tr:nth-child(even)
    {
        Background-Color: rgb(242, 242, 242);
    }
th
    {
        Text-Align: Left;
        Color: rgb(150, 150, 220);
        Padding: 1px 4px 1px 4px;
    }
td
    {
        Vertical-Align: Top;
        Padding: 1px 4px 1px 4px;
    }
"
$head+="</style>"

$RunTime = Get-date

$myoutputfile4 = $FullFolderPath+"\02_Loaded_Dlls.html"
$myHtml1 = $sqlresults15 | select file_version, product_version, debug, patched, prerelease, private_build, special_build, language, company, description, name| `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Loaded DLLs</h2><h3>Ran on : $RunTime</h3>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Loaded DLLs" | Set-Content -Path $myoutputfile4

# Get Trace Flags
$mysql16= "dbcc tracestatus();"

# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults16 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql16
}
else
{
	$sqlresults16 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql16 -User $myuser -Password $mypass
}

if ($sqlresults16 -ne $null)
{
    Write-Output ("Trace Flags Found")
    $myoutputfile4 = $FullFolderPath+"\03_Trace_Flags.html"
    $myHtml1 = $sqlresults16 | select TraceFlag, Status, Global, Session | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Trace Flags</h2><h3>Ran on : $RunTime</h3>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Trace Flags" | Set-Content -Path $myoutputfile4    
}
else
{
    Write-Output "No Trace Flags Set"
}


# Get Device Drivers
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]
if ($WinServer -eq 'localhost' -or $WinServer -eq '.')
{
    $ddrivers = driverquery.exe /nh /fo table /s .
}
else
{
    # Skip driverquery on DMZ Machines - hangs or asks for creds, but cant use them
    if ($myuser.Length -eq 0 -and $mypass.Length -eq 0)
    {
        $ddrivers = driverquery.exe /nh /fo table /s $WinServer
    }
    else
    {
        $ddrivers = $null
    }
}

if ($ddrivers -ne  $null)
{
    $fullFileName = $fullfolderPath+"\04_Device_Drivers.txt"
    New-Item $fullFileName -type file -force  |Out-Null
    Add-Content -Value "Device Drivers for $SQLInstance" -Path $fullFileName -Encoding Ascii  
    Add-Content -Value $ddrivers -Path $fullFileName -Encoding Ascii
}



# Get Running Processes
try
{
    if ($WinServer -eq "localhost" -or $WinServer -eq ".")
    {
        $rprocesses = get-process
    }
    else
    {
        $rprocesses = get-process -ComputerName $WinServer
    }

    if ($rprocesses -ne  $null)
    {
        $myoutputfile4 = $FullFolderPath+"\05_Running_Processes.html"
        $myHtml1 = $rprocesses | select Name, Handles, VM, WS, PM, NPM | `
        ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Running Processes</h2><h3>Ran on : $RunTime</h3>"
        Convertto-Html -head $head -Body "$myHtml1" -Title "Running Processes"| Set-Content -Path $myoutputfile4
    }
}
catch
{
    Write-Output ("Running Processes: Could not connect")
}



# Get NT Services
try
{
    $Services = get-service -ComputerName $WinServer

    if ($Services -ne  $null)
    {
        $myoutputfile4 = $FullFolderPath+"\06_NT_Services.html"
        $myHtml1 = $Services | select Name, DisplayName, Status, StartType | `
        ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>NT Services</h2> <h3>Ran on : $RunTime</h3>"
        Convertto-Html -head $head -Body "$myHtml1" -Title "NT Services" | Set-Content -Path $myoutputfile4
    }
}
catch
{
    Write-Output ("NT Services: Could not connect")
}


# Return to Base
set-location $BaseFolder
