#
#
# Script Name: XDHealthCheck.Ps1
# Created: 10-August -2015

# Author: Suresh Krishnan
# Email: Suresh-a Krishnan
#
# .SYNOPSIS
# Script to monitor and produce xendesktop health check for all Xen desktop sites
# You need to install Desktop Studio from ASD in order to run this script. Also you need to copy ConverttoEXteneded Module from Module folder and place it undre your mydocuments folder
#
# Updated : 02-sep-2015
# Added Hypervisor connection status
#
# Updated : 22-sep-2015
# suresh krishnan – added pending power actions
# Load HTML Table Function
. D:\XDHealthCheck\HTMLTable.ps1

#updated 14-07-2016
# suresh krishnan – get-brokerdesktop on 7.6 has a maxrecord limation hence the script took 40 mins run to complete the script now with change of new functions using gropu-brokermachine
# the script runs less than 2 mins.

# Load Citrix Snapin
Add-PSSnapin citrix*
#Create Site report file
$logtime = get-date -Format "yyyy-MM-dd-HHmm"
$logfile = 'D:\inetpub\wwwroot\winch\xdhealth\'+"XD76Sitereport.html"

#Define Xendesktop Sites in an arry
[string[]]$Adminservers = ("Your Site Names"	)
$yourteamemail = @(
#Define variable
$unregisteredvm = @()
$DodStatus = @()
$RegisteredVM = @()
$TotalVM= @()
$percentregistered = @()
$HypervisorStatus = @()
$PendingPowerActions = @()

foreach ($Adminserver in $Adminservers) {
$result = Get-BrokerController -AdminAddress $Adminserver -ErrorVariable Brokererror
if ($?) {

$Brokermachinestatus = Group-BrokerMachine -Property Registrationstate -AdminAddress $Adminserver
$Brokersession = Group-Brokersession -Property SessionState -AdminAddress $Adminserver

$TotalVM = $Brokermachinestatus | Measure-Object -Property Count -sum | select -ExpandProperty Sum
$unregisteredvm = ($Brokermachinestatus | Where-Object {$_.Name -eq "Unregistered"} | Select-Object Count).Count
$RegisteredVM = ($Brokermachinestatus | Where-Object {$_.Name -eq "Registered"} | Select-Object Count).Count

$ActiveDOD = ($Brokersession | where-Object {$_.Name -eq "Active"} | Select-Object Count).Count
$disconnectedDOD = ($Brokersession | Where-Object {$_.Name -eq "Disconnected"} | Select-Object Count).Count
$RDPDOD = ($Brokersession | Where-Object {$_.Name -eq "NonBrokeredSession"} | Select-Object Count).Count

$PendingPowerActions = (Get-BrokerHostingPowerAction -AdminAddress $Adminserver -maxrecordcount 50000 -state pending).count

if ($TotalVM -ne 0 ){
$percentregistered = "{0:P0}" -f ($RegisteredVM / $TotalVM)
#$percentregistered = "{0:P0}" -f $percentregistered
}
else {$percentregistered = 0}
#Checking Unregister machine count for last hour
$faulstate = Get-BrokerMachine -AdminAddress $Adminserver -FaultState Unregistered -MaxRecordCount 20000
$lasthour = (get-date).AddHours(-1)
$convertdate = $faulstate | select dnsname,lastderegistrationtime,*state
$unregisteredlasthour = $convertdate | where {$_.lastderegistrationtime -ge $lasthour}
$unregisteredlasthourcount = ($unregisteredlasthour | Measure-Object).count
$unregisteredlasthourcount
if ($unregisteredlasthourcount -ge 50 ) {

Send-MailMessage -To $gcstmembers -From "suresh-a.krishnan@db.com" -Subject "$unregisteredlasthourcount machines have become unregistered in the last hour on $Adminserver Please check " -SmtpServer "smtphub.eur.mail.db.com"

}
} else {

$unregisteredvm = 0
$TotalVM = 0
$RegisteredVM = 0
$percentregistered = 0
$PendingPowerActions = 0
$Adminserver = $Adminserver
$ActiveDOD = 0
$disconnectedDOD =0
$RDPDOD = 0
$unregisteredlasthourcount = 0

Send-MailMessage -To $gcstmembers -From "suresh-a.krishnan@db.com" -Subject "$Adminserver Failing to connect database Please check connectivity " -SmtpServer "smtphub.eur.mail.db.com" -Priority High -Body "$brokererror Please check "

}
$DodStatus += New-Object psobject -Property @{UnRegisteredVMCount = $unregisteredvm
TotalDesktops = $TotalVM
RegisteredVM = $RegisteredVM
percentregistered = $percentregistered
pendingpoweractions = $PendingPowerActions
Sitename = $Adminserver
ActiveDOD = $ActiveDOD
DisconnectedDOD = $disconnectedDOD
DODConnectecViaRDP = $RDPDOD
UnRegisterLasthourcount = $unregisteredlasthourcount
}
}
$DodStatus = $DodStatus | sort-object TotalDesktops -Descending | select-object Sitename,TotalDesktops,ActiveDOD,DisconnectedDOD,DODConnectecViaRDP,RegisteredVM,UnRegisteredVMCount,percentregistered,pendingpoweractions,UnRegisterLasthourcount
$DodStatus

#define variable for service status

$controllers = @()
$DDCstatus = @()
$broker =@()
$config = @()
$Hypervisor = @()
$ADAccount = @()
$DesktopRegistered = @()

# DDC Status function
foreach ($Adminserver in $Adminservers){
$controllers += (Get-BrokerController -AdminAddress $Adminserver).DNSName
}
#Checking services againts controller
foreach ($Controller in $Controllers){
$DesktopRegistered = Get-BrokerController -AdminAddress $Controller -DNSName $Controller | select DesktopsRegistered -ExpandProperty DesktopsRegistered
$broker = Get-BrokerServiceStatus -AdminAddress $Controller -ErrorVariable broker
if ($broker.ServiceStatus -eq 'ok')
{

$broker = "OK" }

else {
$broker = "Not Running"}

$config = Get-ConfigServiceStatus -AdminAddress $Controller -ErrorVariable config
if ($config.ServiceStatus -eq 'ok')
{

$config = "OK" }

else {

$config = "Not Running"}

$Hypervisor = Get-HypServiceStatus -AdminAddress $Controller -ErrorVariable Hypervisor
if ($Hypervisor.ServiceStatus -eq 'ok')
{

$Hypervisor = "OK" }

else {
$Hypervisor = "Not Running"}

$ADAccount = Get-AcctServiceStatus -AdminAddress $Controller -ErrorVariable ADAccount
if ($ADAccount.ServiceStatus -eq 'ok')
{

$ADAccount = "OK" }

else {
$ADAccount = "Not Running"}
$DDCstatus+= New-Object psobject -Property @{ControllerName = $Controller
BrokerService = $broker
ConfigService = $config
HypervisorService = $Hypervisor
ADIdentityService = $ADAccount
RegisterDesktopCount = $DesktopRegistered

}
}#forach Admin

$DDCStatus = $DDCstatus | Select-Object ControllerName,ADIdentityService,BrokerService,ConfigService,HypervisorService,RegisterDesktopCount
$DDCstatus

##### THE BELOW FUNCTION CHECKS HYPERVISOR CONNECTION FOR EACH XENDESTTOP SITE #####

$HypervisorStatus = foreach ($Adminserver in $Adminservers){
$hypervischeck = Get-BrokerHypervisorConnection -AdminAddress $Adminserver
foreach ($hypervisor in $hypervischeck) {
New-Object -TypeName PSObject -Property @{ControllerName = $hypervisor.PreferredController
HypervisorName = $hypervisor.Name
Status = $hypervisor.State}
} #foreach $hypervisor
} #foreach $Adminserver

$HypervisorStatus | Select-Object ControllerName,HypervisorName,Status
$HypervisorStatus

#Building HTML Reports.

$HTML = New-HTMLHead -title "Global XenDesktop 7.6 Site Report"
$HTML += " Global Xendesktop 7.6 HealtCheckReport $(get-date -Format F) GMT"

$HTML += " DOD Status Report "
$dodtable = $DodStatus | New-HTMLTable -setAlternating $true |
Add-HTMLTableColor -Argument "0" -Column "TotalDesktops" -AttrValue "background-color:#FF0000;"
$HTML += $dodtable

$HTML += " DDC Service Check "
$ddctable = $DDCstatus | New-HTMLTable -setAlternating $true |
Add-HTMLTableColor -Argument "OK" -Column "ConfigService" -AttrValue "background-color:#00FF00;"|
Add-HTMLTableColor -Argument "OK" -Column "BrokerService" -AttrValue "background-color:#00FF00;"|
Add-HTMLTableColor -Argument "OK" -Column "HypervisorService" -AttrValue "background-color:#00FF00;"|
Add-HTMLTableColor -Argument "OK" -Column "ADIdentityService" -AttrValue "background-color:#00FF00;"|
Add-HTMLTableColor -Argument "Not Running" -Column "ConfigService" -AttrValue "background-color:#FF0000;"|
Add-HTMLTableColor -Argument "Not Running" -Column "BrokerService" -AttrValue "background-color:#FF0000;"|
Add-HTMLTableColor -Argument "Not Running" -Column "HypervisorService" -AttrValue "background-color:#FF0000;"|
Add-HTMLTableColor -Argument "Not Running" -Column "ADIdentityService" -AttrValue "background-color:#FF0000;"

$HTML += $ddctable

$HTML += " HyperVisor Status Report "
$hypervisorTable = $HypervisorStatus | New-HTMLTable -setAlternating $true |
Add-HTMLTableColor -Argument "On" -Column "Status" -AttrValue "background-color:#00FF00;"|
Add-HTMLTableColor -Argument "Unavailable" -Column "Status" -AttrValue "background-color:#FF0000;"

$HTML += $hypervisorTable

#Rename old sitereport.html

Rename-Item -Path $logfile -NewName "$logtime-XD76SiteReport.html" -Force -ErrorAction SilentlyContinue

set-content $logfile $HTML

Send-MailMessage -To "sureshkrishnan83@outlook.com.com" -From "sureshkrishnan83@outlook.com" -Subject "XenDesktop 7.6 Report Testing Mail Functionality on $(Get-Date) GMT" -BodyAsHtml $HTML -SmtpServer "smtpserver"
