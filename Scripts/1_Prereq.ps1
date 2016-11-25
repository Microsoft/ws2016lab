# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
	exit
}

# Skipping 10 lines because if running when all prereqs met, statusbar covers powershell output

 1..10 |% { Write-Host ""}

#############
# Functions #
#############
function WriteInfo($message)
{
    Write-Host $message
}

function WriteInfoHighlighted($message)
{
    Write-Host $message -ForegroundColor Cyan
}

function WriteSuccess($message)
{
    Write-Host $message -ForegroundColor Green
}

function WriteError($message)
{
    Write-Host $message -ForegroundColor Red
}

function WriteErrorAndExit($message)
{
	Write-Host $message -ForegroundColor Red
	Write-Host "Press any key to continue ..."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
	$HOST.UI.RawUI.Flushinputbuffer()
	Exit
}

function  Get-WindowsBuildNumber { 
    $os = Get-WmiObject -Class Win32_OperatingSystem 
    return [int]($os.BuildNumber) 
} 

##############
# Lets start #
##############

# Get workdirectory and Start Time
$workdir       = Split-Path $script:MyInvocation.MyCommand.Path
Start-Transcript -Path "$workdir\Prereq.log"
$StartDateTime = get-date
WriteInfo "Script started at $StartDateTime"

##Load LabConfig....
. "$($workdir)\LabConfig.ps1"

#####################
# Default variables #
#####################

If (!$LabConfig.DomainNetbiosName){
    $LabConfig.DomainNetbiosName="Corp"
}

If (!$LabConfig.DomainName){
    $LabConfig.DomainName="Corp.contoso.com"
}

######################

##########
# Checks #
##########


# Checking for Compatible OS
WriteInfoHighlighted "Checking if OS is Windows 10 TH2/Server 2016 TP4 or newer"

$BuildNumber=Get-WindowsBuildNumber
if ($BuildNumber -ge 10586){
	WriteSuccess "`t OS is Windows 10 TH2/Server 2016 TP4 or newer"
    }else{
    WriteErrorAndExit "`t Windows version  $BuildNumber detected. Version 10586 and newer is needed. Exiting"
}

# Checking Folder Structure
"OSClient","OSServer","Tools\DSC","Tools\ToolsVHD\DiskSpd","OSServer\Packages","OSClient\Packages","Tools\ToolsVHD\SCVMM\ADK","Tools\ToolsVHD\SCVMM\SQL","Tools\ToolsVHD\SCVMM\dotNET","Tools\ToolsVHD\SCVMM\SCVMM","Tools\ToolsVHD\SCVMM\UpdateRollup" | ForEach-Object {
    if (!( Test-Path "$Workdir\$_" )) { New-Item -Type Directory -Path "$workdir\$_" } }
	
"OSServer\Copy_WindowsServer_ISO_or_its_content_here.txt","OSClient\Copy_WindowsClient_ISO_or_its_content_here.txt","OSServer\Packages\Copy_MSU_or_Cab_packages_here.txt","OSClient\Packages\Copy_MSU_or_Cab_packages_here.txt","Tools\ToolsVHD\SCVMM\ADK\Copy_ADK_with_adksetup.exe_here.txt","Tools\ToolsVHD\SCVMM\SQL\Copy_SQL_with_setup.exe_here.txt","Tools\ToolsVHD\SCVMM\dotNET\Copy_microsoft-windows-netfx3-ondemand-package.cab_here.txt","Tools\ToolsVHD\SCVMM\SCVMM\Copy_SCVMM_with_setup.exe_here.txt","Tools\ToolsVHD\SCVMM\UpdateRollup\Copy_SCVMM_Update_Rollup_MSPs_here.txt" | ForEach-Object {
	  if (!( Test-Path "$Workdir\$_" )) { New-Item -Type File -Path "$workdir\$_" } }

# adding scripts for SCVMM install
if (!( Test-Path "$Workdir\Tools\ToolsVHD\SCVMM\1_SQL_Install.ps1" )) {  
    $script = New-Item "$Workdir\Tools\ToolsVHD\SCVMM\1_SQL_Install.ps1" -type File
    $fileContent =  @'

# Sample SQL Install

# You can grab eval version here: http://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2014

# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
	exit
}

$workdir=Split-Path $script:MyInvocation.MyCommand.Path

Start-Transcript -Path "$workdir\SQL_Install.log"

$StartDateTime = get-date
Write-host "Script started at $StartDateTime"

#check for .net 3.5
if ((Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -ne 'Enabled'){
    do{
        If (Test-Path -Path "$workdir\dotNET\microsoft-windows-netfx3-ondemand-package.cab"){
            $dotNET = Get-Item -Path "$workdir\dotNET\microsoft-windows-netfx3-ondemand-package.cab" -ErrorAction SilentlyContinue
		    Write-Host "microsoft-windows-netfx3-ondemand-package.cab found in dotNET folder... installing" -ForegroundColor Cyan
        }else{
            Write-Host "No .NET found in $Workdir\dotNET" -ForegroundColor Cyan
			Write-Host "please browse for dotNET package (microsoft-windows-netfx3-ondemand-package.cab)" -ForegroundColor Green

			[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
			$openFile = New-Object System.Windows.Forms.OpenFileDialog
			$openFile.Filter = "cab files (*.cab)|*.cab|All files (*.*)|*.*" 
			If($openFile.ShowDialog() -eq "OK"){
			   Write-Host  "File $openfile selected" -ForegroundColor Cyan
               $dotNET = Get-Item -Path $openfile.filename -ErrorAction SilentlyContinue
            } 
            if (!$openFile.FileName){
		        Write-Host  "CAB was not selected... Exitting" -ForegroundColor Red
                Write-Host "Press any key to continue ..."
	            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
	            $HOST.UI.RawUI.Flushinputbuffer()
	            Exit 
		     } 
        }
    install-windowsfeature WAS-NET-Environment -Source $dotnet.Directory    
    }
    until ((Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -eq 'Enabled')
}

#install SQL

If (Test-Path -Path "$workdir\SQL\setup.exe"){
    $setupfile = (Get-Item -Path "$workdir\SQL\setup.exe" -ErrorAction SilentlyContinue).fullname
    Write-Host "$Setupfile found..." -ForegroundColor Cyan
}else{
    # Open File dialog
    Write-Host "Please locate SQL Setup.exe" -ForegroundColor Green
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Filter = "setup.exe files |setup.exe|All files (*.*)|*.*" 
    If($openFile.ShowDialog() -eq "OK")
    {
       $setupfile=$openfile.filename
       Write-Host  "File $setupfile selected" -ForegroundColor Cyan
    }
    if (!$openFile.FileName){
		    Write-Host  "setup.exe was not selected... Exitting" -ForegroundColor Red
            Write-Host "Press any key to continue ..."
	        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
	        $HOST.UI.RawUI.Flushinputbuffer()
	        Exit 
	}
}  
     
Write-Host "Installing SQL..." -ForegroundColor Green
& $setupfile /q /ACTION=Install /FEATURES=SQLEngine,SSMS /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT="DomainNameGoesHere\SQL_SA" /SQLSVCPASSWORD="PasswordGoesHere" /SQLSYSADMINACCOUNTS="DomainNameGoesHere\Domain admins" /AGTSVCACCOUNT="DomainNameGoesHere\SQL_Agent" /AGTSVCPASSWORD="PasswordGoesHere" /TCPENABLED=1 /IACCEPTSQLSERVERLICENSETERMS /Indicateprogress /UpdateEnabled=0

Write-Host "Script finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
Stop-Transcript

Write-Host "Job Done..." -ForegroundColor Green
Start-Sleep 5
exit

'@
	$fileContent=$fileContent -replace "PasswordGoesHere",$LabConfig.AdminPassword
    $fileContent=$fileContent -replace "DomainNameGoesHere",$LabConfig.DomainNetbiosName
    Set-Content -path $script -value $fileContent
}

if (!( Test-Path "$Workdir\Tools\ToolsVHD\SCVMM\2_ADK_Install.ps1" )) {  
    $script = New-Item "$Workdir\Tools\ToolsVHD\SCVMM\2_ADK_Install.ps1" -type File
    $fileContent =  @'

#Sample ADK install

# You can grab ADK here: 	https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx

# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
	exit
}


$workdir=Split-Path $script:MyInvocation.MyCommand.Path
Start-Transcript -Path "$workdir\ADK_Install.log"

$StartDateTime = get-date
Write-host "Script started at $StartDateTime"


If (Test-Path -Path "$workdir\ADK\ADKsetup.exe"){
    $setupfile = (Get-Item -Path "$workdir\ADK\ADKsetup.exe" -ErrorAction SilentlyContinue).fullname
}else{
    # Open File dialog
    Write-Host "Please locate ADKSetup.exe" -ForegroundColor Green

    [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Filter = "ADKSetup.exe files |ADKSetup.exe|All files (*.*)|*.*" 
    If($openFile.ShowDialog() -eq "OK")
    {
       $setupfile=$openfile.filename
       Write-Host  "File $setupfile selected" -ForegroundColor Cyan
    }
}

Write-Host "Installing ADK..." -ForegroundColor Cyan

& $setupfile /features OptionID.DeploymentTools OptionID.WindowsPreinstallationEnvironment /quiet

Write-Host "ADK Is being installed..." -ForegroundColor Cyan

do
{
Start-Sleep 1
$adk=$null
$adk=Get-Process adksetup -ErrorAction SilentlyContinue
}
until ($adk -eq $null)

Write-Host "ADK install finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
Stop-Transcript
Write-Host "Job Done..." -ForegroundColor Green
Start-Sleep 5
exit

'@
    Set-Content -path $script -value $fileContent
}

if (!( Test-Path "$Workdir\Tools\ToolsVHD\SCVMM\3_SCVMM_Install.ps1" )) {  
    $script = New-Item "$Workdir\Tools\ToolsVHD\SCVMM\3_SCVMM_Install.ps1" -type File
    $fileContent =  @'

# Sample VMM Install

# You can grab eval version here: http://www.microsoft.com/en-us/evalcenter/evaluate-system-center-technical-preview

# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
	exit
}

$workdir=Split-Path $script:MyInvocation.MyCommand.Path
Start-Transcript -Path "$workdir\SCVMM_Install.log"

$StartDateTime = get-date
Write-host "Script started at $StartDateTime"

do{
    Write-Host "Waiting for SQL Service to start"
    Start-Sleep 1
}until ((get-service MSSQLServer).Status -eq "Running")

If (Test-Path -Path "$workdir\SCVMM\setup.exe"){
    $setupfile = (Get-Item -Path "$workdir\SCVMM\setup.exe" -ErrorAction SilentlyContinue).fullname
    Write-Host "$Setupfile found..." -ForegroundColor Cyan
}else{
# Open File dialog
    Write-Host "Please locate Setup.exe" -ForegroundColor Green

    [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Filter = "setup.exe files |setup.exe|All files (*.*)|*.*" 
    If($openFile.ShowDialog() -eq "OK")
    {
       $setupfile=$openfile.filename
       Write-Host  "File $setupfile selected" -ForegroundColor Cyan
    } 
}

Write-Host "Installing VMM..." -ForegroundColor Green

###Get workdirectory###
$workdir=Split-Path $script:MyInvocation.MyCommand.Path
#$workdir='e:'
#Install VMM
$unattendFile = New-Item "$workdir\VMServer.ini" -type File
$fileContent = @"
[OPTIONS]
CompanyName=Contoso
CreateNewSqlDatabase=1
SqlInstanceName=MSSQLServer
SqlDatabaseName=VirtualManagerDB
SqlMachineName=DC
LibrarySharePath=C:\ProgramData\Virtual Machine Manager Library Files
LibraryShareName=MSSCVMMLibrary
SQMOptIn = 1
MUOptIn = 1
"@
Set-Content $unattendFile $fileContent

& $setupfile /server /i /f $workdir\VMServer.ini /IACCEPTSCEULA /VmmServiceDomain DomainNameGoesHere /VmmServiceUserName vmm_SA /VmmServiceUserPassword PasswordGoesHere

do
{
Write-Host "VMM is being installed..." -ForegroundColor Cyan
Start-Sleep 10
$vmm=$null
$vmm=Get-Process | Where-Object {$_.Description -eq "Virtual Machine Manager Setup"} -ErrorAction SilentlyContinue
}
until ($vmm -eq $null)

Remove-Item "$workdir\VMServer.ini" -ErrorAction Ignore

Write-Host "VMM is Installed" -ForegroundColor Green

Write-Host "VMM install finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"

$StartDateTime = get-date
$URs=(Get-ChildItem -Path $Workdir\UpdateRollup -Recurse | where extension -eq .msp).FullName
Stop-Service SCVMM*
Foreach ($UR in $URs){
    msiexec.exe /update $UR /quiet /norestart
    do{
        Write-Host "UR $UR is being installed..." -ForegroundColor Cyan
        Start-Sleep 10
        $msiexec=$null
        $msiexec=Get-Process msiexec -ErrorAction SilentlyContinue
    }until ($msiexect -eq $null)
Start-Sleep 10
}

If ($URs){
    Write-Host "UpdateRollups install finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
}

Stop-Transcript

Write-Host "Job Done..." -ForegroundColor Green
start-sleep 5
Exit

'@
	$fileContent=$fileContent -replace "PasswordGoesHere",$LabConfig.AdminPassword
    $fileContent=$fileContent -replace "DomainNameGoesHere",$LabConfig.DomainNetbiosName
    Set-Content -path $script -value $fileContent
}

##########################
# Some stuff to download #
##########################

# Downloading diskspd if its not in tools folder
WriteInfoHighlighted "Testing diskspd presence"
If ( Test-Path -Path "$workdir\Tools\ToolsVHD\DiskSpd\diskspd.exe" ) {
		WriteSuccess "`t Diskspd is present, skipping download"
}else{ 
		WriteInfo "`t Diskspd not there - Downloading diskspd"
		try {
			$webcontent  = Invoke-WebRequest -Uri aka.ms/diskspd -UseBasicParsing
			$downloadurl = $webcontent.BaseResponse.ResponseUri.AbsoluteUri.Substring(0,$webcontent.BaseResponse.ResponseUri.AbsoluteUri.LastIndexOf('/'))+($webcontent.Links | where-object { $_.'data-url' -match '/Diskspd.*zip$' }|Select-Object -ExpandProperty "data-url")
			Invoke-WebRequest -Uri $downloadurl -OutFile "$workdir\Tools\ToolsVHD\DiskSpd\diskspd.zip"
		}catch{
			WriteError "`t Failed to download Diskspd!"
		}
		# Unnzipping and extracting just diskspd.exe x64
		Expand-Archive "$workdir\Tools\ToolsVHD\DiskSpd\diskspd.zip" -DestinationPath "$workdir\Tools\ToolsVHD\DiskSpd\Unzip"
		Copy-Item -Path (Get-ChildItem -Path "$workdir\tools\toolsvhd\diskspd\" -Recurse | Where-Object {$_.Directory -like '*amd64fre*' -and $_.name -eq 'diskspd.exe' }).fullname -Destination "$workdir\Tools\ToolsVHD\DiskSpd\"
		Remove-Item -Path "$workdir\Tools\ToolsVHD\DiskSpd\diskspd.zip"
		Remove-Item -Path "$workdir\Tools\ToolsVHD\DiskSpd\Unzip" -Recurse -Force
}

# Download convert-windowsimage if its not in tools folder
WriteInfoHighlighted "Testing convert-windowsimage presence"
If ( Test-Path -Path "$workdir\Tools\convert-windowsimage.ps1" ) {
	WriteSuccess "`t Convert-windowsimage.ps1 is present, skipping download"
}else{ 
		WriteInfo "`t Downloading Convert-WindowsImage"
		try{
			Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/hyperv-tools/Convert-WindowsImage/Convert-WindowsImage.ps1 -OutFile "$workdir\Tools\convert-windowsimage.ps1"
		}catch{
			WriteError "`t Failed to download convert-windowsimage.ps1!"
		}
}	


# Downloading modules into Tools folder if needed.

$modules=("xActiveDirectory","2.10.0.0"),("xDHCpServer","1.3.0.0"),("xNetworking","2.8.0.0"),("xPSDesiredStateConfiguration","3.9.0.0")
foreach ($module in $modules){
	#testing if modules are present
	WriteInfoHighlighted "Testing if modules are present" 
	$modulename=$module[0]
    $moduleversion=$module[1]
	if (!(Test-Path $workdir'\Tools\DSC\'$modulename'\')){
		WriteInfo "`t Module $module not found... Downloading"
		#Install NuGET package provider   
		if ((Get-PackageProvider -Name NuGet) -eq $null){   
			Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
			}
		Find-DscResource -moduleName $modulename -RequiredVersion $moduleversion | Save-Module -Path $workdir'\Tools\DSC'
	}else{
		WriteSuccess "`t Module $modulename version found... Skipping Download"
	}
}

# Installing DSC modules if needed
foreach ($module in $modules) {
    WriteInfoHighlighted "Testing DSC Module $module Presence"
    # Check if Module is installed
    if ((Get-DscResource -Module $Module[0] | where-object {$_.version -eq $module[1]}) -eq $Null) {
        # module is not installed - install it
        WriteInfo "`t Module $module will be installed"
        $modulename=$module[0]
        $moduleversion=$module[1]
        Copy-item -Path "$workdir\Tools\DSC\$modulename" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force
        WriteSuccess "`t Module was installed."
        Get-DscResource -Module $modulename
    } else {
        # module is already installed
        WriteSuccess "`t Module $Module is already installed"
    }
}

#############
# finishing #
#############

WriteInfo "Script finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
Stop-Transcript
WriteSuccess "Press any key to continue..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL