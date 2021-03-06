<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			January 2, 2018
	Version:		2.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script automates the full database backup process of the VMware VCSA 6.5 or higher. 
		The script also auto deletes any version previous database backup based on a maximum day 
		threshold you set.

	.DESCRIPTION
		Use this script to backup the full VMware VCSA 6.5 or higher datebase. For the first time use,
		run this script manually with administrator rights to correctly install any PowerShell modules needed
		for this script to properly run. The first time this script is run it will also create a logs directory,
		AnswserFile.csv, AES.key, BackupEncryptionPassword.txt (optional), MgrCreds.xml, and ProtocolCreds.xml. 
		This script creates a current date named folder on a target destination and places a backup copy 
		of the database in that folder.
		This script will store all vCenter Username/Password and the Backup Location Password in
		an AES encrypted flat format to allow for future runnings of this script.
		Use this script with a Windows Task Scheduler or VMware Orchestrator to schedule/automate the 
		backup process on a timely bases. 

	.NOTES
		Credit goes to @AlanRenouf and @vBrianGraf for the Backup-VCSAToFile Function
		User Account must have the following VCSA rights: 
		This script has been tested using FileZilla FTP Server using protocols including: FTP, FTPS 
		This script was tested with a QNAP using protocol SCP
		This script was tested using CrushFTP Server using protocol HTTPS
		This script was not tested using protocol HTTP
		FTPS Note: Get-FTPChildItem "-Recurse" Feature does not work properly with FTPS with CrushFTP Server
		This script does not do automatic clean up of HTTP or HTTPS protocols due to special programming needed for either protocol
		This script requires a VMware PowerCLI minimum version 6.5.3 or greater

	.TROUBLESHOOTING
		If the backup process fails, delete User.txt, Password.txt and run script manually again to fill in proper info.
		If backup process continues to fail and you are using backup encryption, change Anwserfile UseBackupPassword to No and retest.
		If you receive errors similar to: 
		Backup-VCSAToFile : A server error occurred: 'com.vmware.vapi.std.errors.unauthorized': Unable to authorize user, 
		reboot VCSA and verify that the vAPI Endpoint VCSA service and all other services have no errors.
		If clean up process fails, verify that the PowerShell module clean up process works manually. If it does not
		consult your backup location storage providers support for proper assistance or change backup protocols.
#>

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name VMware.PowerCLI -MinimumVersion 6.5.3.6870460) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "Importing PowerShell Module VMware PowerCLI Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI does not exist"
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Uninstalling any older versions of the VMware PowerCLI Module"
	Get-Module VMware.PowerCLI | Uninstall-Module -Force
	Write-Host "Installing Newest version of VMware PowerCLI PowerShell Module"
	Install-Module -Name VMware.PowerCLI -Scope AllUsers
	Write-Host "Creating a Desktop shortcut to the VMware PowerCLI Module"
	$AppLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	$Arguments = '-noe -c "Import-Module VMware.PowerCLI"'
	$WshShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\VMware PowerCLI.lnk")
	$Shortcut.TargetPath = $AppLocation
	$Shortcut.Arguments = $Arguments
	$ShortCut.Hotkey = "CTRL+SHIFT+V"
	$Shortcut.IconLocation = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe,1"
	$Shortcut.Description ="Launch VMware PowerCLI"
	$Shortcut.WorkingDirectory ="C:\"
	$Shortcut.Save()
	Write-Host "Shortcut Created"
	Write-Host "You may use the CTRL+SHIFT+V method to open VMware PowerCLI"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "PowerShell Module VMware PowerCLI Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#Clear
}
#Needed for FTP & FTPS File Cleanup
if (Get-Module -ListAvailable -Name PSFTP) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "Importing PowerShell Module PSFTP"
	Import-Module -Name PSFTP
	Write-Host "Importing PowerShell Module PSFTP Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module PSFTP does not exist"
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Installing New version of PSFTP"
	Install-Module -Name PSFTP -Scope AllUsers
	Write-Host "Importing PowerShell Module PSFTP"
	Import-Module -Name PSFTP
	Write-Host "PowerShell Module PSFTP Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
}
#Needed for SCP File Cleanup
if (Get-Module -ListAvailable -Name WinSCP) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "Importing PowerShell Module WinSCP"
	Import-Module -Name WinSCP
	Write-Host "Importing PowerShell Module WinSCP Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module WinSCP does not exist"
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Installing New version of WinSCP"
	Install-Module -Name WinSCP -Scope AllUsers
	Write-Host "Importing PowerShell Module WinSCP"
	Import-Module -Name WinSCP
	Write-Host "PowerShell Module WinSCP Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
}

##Set Variables
##Get Current Path
$pwd = pwd
##If answerfile exists, Import it for use or create one.
$AnswerFile = $pwd.path+"\"+"AnswerFile.csv"
If (Test-Path $AnswerFile)
{
	##Import File
	Write-Host "Answer file found, importing answer file"$AnswerFile
	$Answer = Import-Csv $AnswerFile
	#Check for Old Version of Files, If found delete and request to re-input data
	IF ($Answer.Version -eq "1")
	{
		$Location = $pwd.path
		$LocationAllFiles = $Location + "\*"
		Remove-Item AES.key -confirm:$false
		Remove-Item AnswerFile.csv -confirm:$false
		Remove-Item LocationPassword.txt -confirm:$false
		Remove-Item Password.txt -confirm:$false
		Remove-Item User.txt -confirm:$false
		Remove-Item BackupCreds.txt -confirm:$false
		Remove-Item MgrCreds.xml -confirm:$false
		Remove-Item ProtocolCreds.xml -confirm:$false
		Write-Host "Old Version of Data Found. Deleteing Old Data. Please input all configuration again."
	}
	#Check for Current Version File
	If (Test-Path $AnswerFile){
		##Import File
		Write-Host "Answer file found, importing answer file"$AnswerFile
		$Answer = Import-Csv $AnswerFile
		ForEach($Line in $Answer)
		{
			$VERSION = $Line.Version
			Write-Host "Version specified in file is:"$Version
			$SUBVERSION = $Line.SubVersion
			Write-Host "SubVersion specified in file is:"$SubVersion
			$VCENTER = $Line.vCenter
			Write-Host "vCenter specified in file is:"$vCenter
			$LOCATIONTYPE = $Line.LocationType
			Write-Host "Location Type is:"$LocationType
			$LOCATIONSERVER = $Line.LocationServer
			Write-Host "Location Server is:"$LOCATIONSERVER
			$LOCATION = $Line.Location
			Write-Host "Location to store backup is:"$LOCATION
			$COMMENTS = $Line.COMMENTS
			Write-Host "Comments for Backup are:"$COMMENTS
			$ExportDays = $Line.ExportDays
			Write-Host "Will keep DB Backup for"$ExportDays" days"
			$SmtpServer = $Line.SmtpServer
			Write-Host "SMTP Server will be: "$SmtpServer
			$MsgFrom = $Line.MsgFrom
			Write-Host "Emails will be sent from: "$MsgFrom
			$MsgTo = $Line.MsgTo
			Write-Host "Emails will be sent to: "$MsgTo
			$USEBACKUPPASSWORD = $Line.UseBackupPassword
				
			Write-Host "Continuing..."
			Start-Sleep -Seconds 2
		}
	} 
	Else {
		$Answers_List = @()
		$Answers="" | Select Version,SubVersion,vCenter,LocationType,LocationServer,Location,Comments,ExportDays,SmtpServer,MsgFrom,MsgTo,UseBackupPassword
		Write-Host "Answer file NOT found. Please input information to continue."
		$Version = "2"
		$Answers.Version = $Version
		$SubVersion = "0"
		$Answers.SubVersion = $SubVersion
		[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
		$vCenter = [Microsoft.VisualBasic.Interaction]::InputBox("Input vCenter FQDN or IP
		Example: vcsa.contso.com or 10.1.1.1
		", "vCenter")
		$Answers.vCenter = $vCenter
		$LOCATIONTYPES = @("FTP","FTPS","SCP","HTTP","HTTPS")
		If($LOCATIONTYPES.Count -gt 1)
		{
			   $LOCATIONTYPE = $LOCATIONTYPES | Out-GridView -Title 'Select Protocol to Use' -OutputMode Single
		}else {$LOCATIONTYPE = "FTP"}
		$Answers.LocationType = $LOCATIONTYPE
		$LOCATIONSERVER = [Microsoft.VisualBasic.Interaction]::InputBox("Input Backup Location Server FQDN or IP.
		Example: ftp.contso.com or 10.1.1.1
		")
		$Answers.LocationServer = $LOCATIONSERVER
		$LOCATION = [Microsoft.VisualBasic.Interaction]::InputBox("Input Location of where Backup Should be sent.
		Example: VMware/VCSA/DB
		Note: Place the Backups in a seperate folder from all other items
		")
		$Answers.Location = $LOCATION
		$COMMENTS = [Microsoft.VisualBasic.Interaction]::InputBox("Input Backup Comments.
		Example: Weekly Backup of VCSA
		(OPTIONAL) (Leave blank if you do not wish to use this)
		")
		$Answers.Comments = $COMMENTS
		$EXPORTDAYS = [Microsoft.VisualBasic.Interaction]::InputBox("Select Amount of days to keep DB Backup for
		Example: 90
		")
		$Answers.ExportDays = $EXPORTDAYS
		$SMTPSERVER = [Microsoft.VisualBasic.Interaction]::InputBox("Type in a SMTP Server IP or FQDN for Email Report:
		Example: smtp.contso.com 10.1.1.1
		")
		$Answers.SmtpServer = $SMTPSERVER
		$MSGFROM = [Microsoft.VisualBasic.Interaction]::InputBox("Type in the from Email From Address
		Example: PowerCLI@domain.com
		")
		$Answers.MsgFrom = $MSGFROM
		$MSGTO = [Microsoft.VisualBasic.Interaction]::InputBox("Type in the list of Email Addresses to Send the Report to
		Example: user@domain.com 
		Note: For multiple emails do comma seperated: test@test.com,test2@test.com
		")
		$Answers.MsgTo = $MSGTO
		$USEBACKUPPASSWORDS = @("No","Yes")
		If($USEBACKUPPASSWORDS.Count -gt 1)
		{
			   $USEBACKUPPASSWORD = $USEBACKUPPASSWORDS | Out-GridView -Title 'Use Password to Encrypt Backup' -OutputMode Single
		}else {$USEBACKUPPASSWORD = "No"}
		$Answers.UseBackupPassword = $USEBACKUPPASSWORD

		$Answers_List += $Answers
		$Answers_List | Format-Table -AutoSize
		Write-Host "Exporting Information to File"$AnswerFile
		$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
	}
}

##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"AES.key"
If (Test-Path $KeyFile){
Write-Host "AES File Exists"
$Key = Get-Content $KeyFile
Write-Host "Continuing..."
}
Else {
$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile
}

##Create Secure XML Credential File for vCenter
$MgrCreds = $pwd.path+"\"+"MgrCreds.xml"
If (Test-Path $MgrCreds){
Write-Host "MgrCreds.xml file found"
Write-Host "Continuing..."
$ImportObject = Import-Clixml $MgrCreds
$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}
Else {
$newPScreds = Get-Credential -message "Enter vCenter admin creds here:"
#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
#$rng.GetBytes($Key)
$exportObject = New-Object psobject -Property @{
    UserName = $newPScreds.UserName
    Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
}
$exportObject | Export-Clixml MgrCreds.xml
$MyCredential = $newPScreds
}

##Create Secure XML Credential File for vCenter/NSX Access
$ProtocolCreds = $pwd.path+"\"+"ProtocolCreds.xml"
If (Test-Path $ProtocolCreds){
Write-Host "ProtocolCreds.xml file found"
Write-Host "Continuing..."
$ImportObject = Import-Clixml $ProtocolCreds
$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
$ProtocolCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}
Else {
$ProtocolNewPScreds = Get-Credential -message "Enter the Backup Protocol Creds here:"
#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
#$rng.GetBytes($Key)
$exportObject = New-Object psobject -Property @{
    UserName = $ProtocolNewPScreds.UserName
    Password = ConvertFrom-SecureString -SecureString $ProtocolNewPScreds.Password -Key $Key
}
$exportObject | Export-Clixml ProtocolCreds.xml
$ProtocolCredential = $ProtocolNewPScreds
}

##Set Protocol Access Creds to Variables
$LOCATIONUSER = $ProtocolCredential.UserName
$SecureLocationPassword = $ProtocolCredential.Password
$UnsecureLocationPassword = (New-Object PSCredential "user",$SecureLocationPassword).GetNetworkCredential().Password

##Create Secure Backup Creds File for Encrypting your VCSA Backup
$BackupCreds = $pwd.path+"\"+"BackupCreds.txt"
if ($USEBACKUPPASSWORD -eq "yes")
{
	If (Test-Path $BackupCreds){
	Write-Host "BackupCreds.txt file found"
	Write-Host "Continuing..."
	$SecureBackupPassword = (Get-Content $BackupCreds | ConvertTo-SecureString -Key $Key)
	$BackupPassword = (New-Object PSCredential "user",$SecureBackupPassword).GetNetworkCredential().Password
	}
	Else {
	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
	$BackupPassword = [Microsoft.VisualBasic.Interaction]::InputBox("Type in the Encryption Password for VCSA Backups `
	`n`
	Password requirements: `
	At least 8 characters, but no more than 20 characters. At least 1 uppercase letter. `
	At least 1 lowercase letter. At least 1 numeric digit. At least 1 special character (any character not in [0-9,a-z,A-Z]). `
	Only visible ASCII characters (for example, no space). 
	")
	##Export to AES Encrypted File
	#Convert Backup Password to Secure String
	$SecureBackupPassword = ConvertTo-SecureString $BackupPassword -asplaintext -force 
	$SecureBackupPassword| ConvertFrom-SecureString -key $Key | Out-File $BackupCreds
	}
}

##Get Date Info for naming of snapshot variable
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}
Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Create Function Backup-VCSAToFile 
##Reference https://www.brianjgraf.com/2016/11/18/vsphere-6-5-automate-vcsa-backup/
##Thank you Brian Graf!
##Updated for PowerCLI 6.5.3
Function Backup-VCSAToFile {
<#
    .NOTES
    ===========================================================================
	 Created by:   	Brian Graf
     Date:          October 30, 2016
	 Organization: 	VMware
     Blog:          www.vtagion.com
     Twitter:       @vBrianGraf
	===========================================================================

	.SYNOPSIS
		This function will allow you to create a full or partial backup of your
    VCSA appliance. (vSphere 6.5 and higher)
	
	.DESCRIPTION
		Use this function to backup your VCSA to a remote location

	.EXAMPLE
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword = "VMw@re123"
        $Comment = "First API Backup"
        $LocationType = "FTP"
        $location = "10.144.99.5/vcsabackup-$((Get-Date).ToString('yyyy-MM-dd-hh-mm'))"
        $LocationUser = "admin"
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$locationPassword = "VMw@re123"
		PS C:\> Backup-VCSAToFile -BackupPassword $BackupPassword  -LocationType $LocationType -Location $location -LocationUser $LocationUser -LocationPassword $locationPassword -Comment "This is a demo" -ShowProgress -FullBackup

	
	.NOTES
        Credit goes to @AlanRenouf for sharing the base of this function with me which I was able to take and make more robust as well as add in progress indicators
        You must be connected to the CisService for this to work, if you are not connected, the function will prompt you for your credentials
		If a -LocationType is not chosen, the function will default to FTP.
        The destination location for a backup must be an empty folder (easiest to use the get-date cmdlet in the location)
        -ShowProgress will give you a progressbar as well as updates in the console
        -SeatBackup will only backup the config whereas -Fullbackup grabs the historical data as well
#>
    param (
        [Parameter(ParameterSetName='FullBackup')]
        [switch]$FullBackup,
        [Parameter(ParameterSetName='SeatBackup')]
        [switch]$SeatBackup,
        [ValidateSet('FTPS', 'HTTP', 'SCP', 'HTTPS', 'FTP')]
        $LocationType = "FTP",
        $Location,
        $LocationUser,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword,
        $Comment = "Backup job",
        [switch]$ShowProgress
    )
    Begin {
        if (!($global:DefaultCisServers)){ 
            [System.Windows.Forms.MessageBox]::Show("It appears you have not created a connection to the CisServer. You will now be prompted to enter your vCenter credentials to continue" , "Connect to CisServer") | out-null
            $Connection = Connect-CisServer $global:DefaultVIServer 
        } else {
            $Connection = $global:DefaultCisServers
        }
        if ($FullBackup) {$parts = @("common","seat")}
        if ($SeatBackup) {$parts = @("seat")}
    }
    Process{
        $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
        $CreateSpec = $BackupAPI.Help.create.piece.Create()
        $CreateSpec.parts = $parts
        $CreateSpec.backup_password = $BackupPassword
        $CreateSpec.location_type = $LocationType
        $CreateSpec.location = $Location
        $CreateSpec.location_user = $LocationUser
        $CreateSpec.location_password = $LocationPassword
        $CreateSpec.comment = $Comment
        try {
            $BackupJob = $BackupAPI.create($CreateSpec)
        }
        catch {
            Write-Error $Error[0].exception.Message
        }
            

        If ($ShowProgress){
            do {
                $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
                $progress = ($BackupAPI.get("$($BackupJob.ID)").progress)
                Write-Progress -Activity "Backing up VCSA"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
                start-sleep -seconds 5
            } until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

            $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
        } 
        Else {
            $BackupJob | select id, progress, state
        }
    }
    End {}
}

Function Get-VCSABackupJobs {
<#
    .NOTES
    ===========================================================================
	 Created by:   	Brian Graf
     Date:          October 30, 2016
	 Organization: 	VMware
     Blog:          www.vtagion.com
     Twitter:       @vBrianGraf
	===========================================================================

	.SYNOPSIS
		Get-VCSABackupJobs returns a list of all backup jobs VCSA has ever performed (vSphere 6.5 and higher)
	
	.DESCRIPTION
		Get-VCSABackupJobs returns a list of all backup jobs VCSA has ever performed

	.EXAMPLE
		PS C:\> Get-VCSABackupJobs
	
	.NOTES
		The values returned are read as follows:
        YYYYMMDD-hhmmss-vcsabuildnumber
        You can pipe the results of this function into the Get-VCSABackupStatus function
        Get-VCSABackupJobs | select -First 1 | Get-VCSABackupStatus <- Most recent backup
#>
    param (
        [switch]$ShowNewest
    )
    Begin {
        if (!($global:DefaultCisServers)){ 
            [System.Windows.Forms.MessageBox]::Show("It appears you have not created a connection to the CisServer. You will now be prompted to enter your vCenter credentials to continue" , "Connect to CisServer") | out-null
            $Connection = Connect-CisServer $global:DefaultVIServer 
        } else {
            $Connection = $global:DefaultCisServers
        }
    }
    Process{
       
        $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job

        try {
            if ($ShowNewest) {
                $results = $BackupAPI.list()
                $results[0]
            } else {
                $BackupAPI.list()
            }
        }
        catch {
            Write-Error $Error[0].exception.Message
        }

        }

    End {}
}

Function Get-VCSABackupStatus {
<#
    .NOTES
    ===========================================================================
	 Created by:   	Brian Graf
     Date:          October 30, 2016
	 Organization: 	VMware
     Blog:          www.vtagion.com
     Twitter:       @vBrianGraf
	===========================================================================

	.SYNOPSIS
		Returns the ID, Progress, and State of a VCSA backup (vSphere 6.5 and higher)
	
	.DESCRIPTION
		Returns the ID, Progress, and State of a VCSA backup

	.EXAMPLE
		PS C:\> $backups = Get-VCSABackupJobs
                $backups[0] | Get-VCSABackupStatus
	
	.NOTES
		The BackupID can be piped in from the Get-VCSABackupJobs function and can return multiple job statuses
#>
    Param (
        [parameter(ValueFromPipeline=$True)]
        [string[]]$BackupID
    )
 Begin {
        if (!($global:DefaultCisServers)){ 
            [System.Windows.Forms.MessageBox]::Show("It appears you have not created a connection to the CisServer. You will now be prompted to enter your vCenter credentials to continue" , "Connect to CisServer") | out-null
            $Connection = Connect-CisServer $global:DefaultVIServer 
        } else {
            $Connection = $global:DefaultCisServers
        }
        
        $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
 }
    Process{
       
        foreach ($id in $BackupID) {
            $BackupAPI.get("$id") | select id, progress, state
        }
        

    }

    End {}
}

##################################Start of Scritp#########################################################

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##List Settings
#Being stated 2nd time after Transcript has started to document info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Settings will be: "
Write-Host "Version specified in file is: 		"$VERSION
Write-Host "SubVersion specified in file is: 	"$SUBVERSION
Write-Host "vCenter specified in file is: 		"$VCENTER
Write-Host "Location Type is: 			"$LOCATIONTYPE
Write-Host "Location Server is: 			"$LOCATIONSERVER 
Write-Host "Location to store backup is: 		"$LOCATION
Write-Host "Location User Account is: 		"$LOCATIONUSER
Write-Host "Comments for Backup are: 		"$COMMENTS
Write-Host "Will keep DB Backup for: 		"$EXPORTDAYS" days"
Write-Host "SMTP Server will be: 			"$SMTPSERVER
Write-Host "Emails will be sent from: 		"$MSGFROM
Write-Host "Emails will be sent to: 		"$MSGTO
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from any open vCenter Sessions,
#This can cause problems if there are any
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from any Open vCenter Sessions"
TRY
{Disconnect-VIServer * -Confirm:$false}
CATCH
{Write-Host "No Open vCenter Sessions found"}
Write-Host "Disconnecting from any Open CIS vCenter Server Sessions"
if($global:DefaultCisServers)
{
	Disconnect-CisServer * -Confirm:$false
}
ELSE{
	Write-Host "No Open CIS Server Sessions found"
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Connect to vCenter Server
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting to vCenter "$vCenter
Connect-VIServer -server $vCenter -Credential $MyCredential
Write-Host "Connecting to CIS Server "$vCenter
Connect-CisServer -server $vCenter -Credential $MyCredential
Write-Host "Connected to VIServer/CIServer "$vCenter
Write-Host "Waiting 10 Seconds before beginning processes"
Start-Sleep -Seconds 10
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Set Date/Time for Location Folder Creation
$LocationWithDate = $LocationServer + "/" + $Location + "/$((Get-Date).ToString('MMM-dd-yyyy_HH-mm'))"
Write-Host "Backup Location will be: " $LocationType"://"$LocationWithDate
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Check if optional variables are filled in
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating Backup Command for Optional Variables"
$BackupCommand = "Backup-VCSAToFile -FullBackup -BackupPassword '$BackupPassword' -LocationType '$LocationType' -Location '$LocationWithDate' -LocationUser '$LocationUser' -LocationPassword '$UnsecureLocationPassword' -Comment '$Comments' -ShowProgress"
If (!$BackupPassword)
{
	##If No Backup Password is setup (Optional)
	Write-Host "Encryption Password not found. Removing Variable"
	$BackupCommand = $BackupCommand -Replace "-BackupPassword '$BackupPassword' ",""
}
If (!$Comments)
{
	##If no Comment is set (Optional)
	Write-Host "Comments not found. Removing Variable"
	$BackupCommand = $BackupCommand -Replace "-Comment '$Comments' ",""
}
Write-Host "Updating Backup Command for Optional Variables Completed"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Testing Backup Location
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Pinging Backup Location Server to verify connectivity"
PING $LOCATIONSERVER -n 10
Write-Host "Pinging Backup Location Server to verify connectivity Completed"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Backup
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "VCSA Backup Process Starting"
$BACKUPStartTime = (Get-Date -format "MMM-dd-yyyy HH-mm-ss")
$BACKUPSTARTTIMESW = [Diagnostics.Stopwatch]::StartNew()
$BackupResults = Invoke-Expression $BackupCommand
$BACKUPEndTime = (Get-Date -format "MMM-dd-yyyy HH-mm-ss")
Write-Host "Completed VCSA Backup Process"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$BACKUPSTARTTIMESW.STOP()
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host "Listing Backup Results"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$BackupResults | Write-Host
Write-Host "VCSA Backup Process Started Completed"
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Listing results and Verifying Backup success
$BackupResultsLast = $BackupResults.State | Select-Object -Last 1
If ($BackupResultsLast -eq 'SUCCEEDED'){
Write-Host "Backup was Successful"
$BackupSuccess = "Successful"
}Else{
Write-Host "Backup Failed"
$BackupSuccess = "Failed"
}

##Disconnect from vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting vCenter Session"
Disconnect-VIServer $vCenter -confirm:$false
Write-Host "Disconnecting CIS Server Session"
Disconnect-CisServer $vCenter -confirm:$false
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Delete Older versions of Export
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$limit = (Get-Date).AddDays(-$ExportDays)
Write-Host "Data older than this date will be deleted: "$limit
IF ($LocationType -eq "FTP"){
	#Import-Module -Name PSFTP
	$FTPCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocationUser, $SecureLocationPassword
	$FTPLocation = "ftp://" + $LocationServer
	Set-FTPConnection -Credentials $FTPCredential -Server $FTPLocation -Session MyFTPSession -UsePassive
	$Session = Get-FTPConnection -Session MyFTPSession
	$DeleteFolderList = Get-FTPChildItem -Session $Session -Path $LOCATION -Recurse | Where-Object { $_.Name -ne "." -and $_.Name -ne ".." } | Where-Object { $_.ModifiedDate -lt $limit }
	Write-Host "FTP Delete list is:"#$DeleteFolderList
	Write-Output $DeleteFolderList
	ForEach ($Line in $DeleteFolderList){
		Write-Host $Line
		Remove-FTPItem -Session $Session -Path  $Line.FullName -Recurse -Confirm:$FALSE
		Write-Host "Removal of " $LinePath " Completed"
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	}
 }
IF ($LocationType -eq "FTPS"){
	#Import-Module -Name PSFTP
	$FTPCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocationUser, $SecureLocationPassword
	$FTPLocation = "ftp://" + $LocationServer
	Set-FTPConnection -Credentials $FTPCredential -Server $FTPLocation -Session MyFTPSession -EnableSSL -ignoreCert -UsePassive
	$Session = Get-FTPConnection -Session MyFTPSession
	$DeleteFolderList = Get-FTPChildItem -Session $Session -Path $LOCATION -Recurse | Where-Object { $_.Name -ne "." -and $_.Name -ne ".." } | Where-Object { $_.ModifiedDate -lt $limit }
	Write-Host "FTP Delete list is:"#$DeleteFolderList
	Write-Output $DeleteFolderList
	ForEach ($Line in $DeleteFolderList){
		Write-Host $Line
		Remove-FTPItem -Session $Session -Path  $Line.FullName -Recurse -Confirm:$FALSE
		Write-Host "Removal of " $Line.FullName " Completed"
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	}
}
 IF ($LocationType -eq "SCP"){
	#Import-Module -Name WinSCP
	$WINSCPCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocationUser, $SecureLocationPassword
	$Session = New-WinSCPSession -SessionOption (New-WinSCPSessionOption -HostName $LocationServer -Protocol $LocationType -GiveUpSecurityAndAcceptAnySshHostKey -Credential $WINSCPCredential)
	$DeleteFolderList = Get-WinSCPChildItem -Path $location -WinSCPSession $Session | Where-Object { $_.LastWriteTime -lt $limit }
	Write-Host "Folder Delete list is:"$DeleteFolderList 
	ForEach ($Line in $DeleteFolderList){
		Remove-WinSCPItem -WinSCPSession $Session -Path $Line.FullName -Confirm:$False
		Write-Host "Removal of " $Line.FullName " Completed"
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
		}
}
IF ($LocationType -eq "HTTP"){
Write-Host "This process must be customized per your environment"
}
IF ($LocationType -eq "HTTPS"){
Write-Host "This process must be customized per your environment"
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Stopping Logging
#Note: Must stop transcriptting prior to sending email report with attached log file
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "All Processes Completed"
Write-Host "Stopping Transcript"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Stop-Transcript
 
#Send Email Report
IF ($smtpServer){
$att = new-object Net.Mail.Attachment($LOGFILE)
$STARTTIMESW.STOP()
$CompletionTime = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = $MSGFROM
$msg.To.Add($MSGTO)
$msg.Subject = "VCSA DB Backup Report for " + $vCenter + " - " + $BackupSuccess
$BodyLine1 = "Attached is the log file from this VCSA DB Backup Job. "
$BodyLine2 = "Backup "  + $BackupSuccess
$BodyLine3 = "Backup Script Start Time: " + $StartTime
$BodyLine4 = "Backup Script Completion Time: " + $CompletionTime
$BodyLine5 = "Total Backup Script Time: " + $STARTTIMESW.Elapsed.TotalMinutes + " Minutes"
$BodyLine6 = "Backup Start Time: " + $BACKUPStartTime
$BodyLine7 = "Backup Completion Time: " + $BACKUPEndTime
$BodyLine8 = "Total Backup Time: " + $BACKUPSTARTTIMESW.Elapsed.TotalMinutes + " Minutes"
$BodyLine9 = "Backup Location was: " + $LocationType + "://" + $LocationWithDate
$BodyLine10 = "Data deleted after day limit includes: " + $DeleteFolderList -Join ', '
If ($BackupPassword)
{
	##If No Backup Password is setup (Optional)
	Write-Host "Encryption Password in use."
	$BodyLine11 = "Backup was Encypted using a Backup Password to Encrypt this Backup."
}
$msg.Body = "
$BodyLine1 `n `
$BodyLine2 `n`n `
$BodyLine3 `n
$BodyLine4 `n
$BodyLine5 `n`n`n `
$BodyLine6 `n
$BodyLine7 `n
$BodyLine8 `n`n`n `
$BodyLine9 `
$BodyLine10 `
$BodyLine11 `
"
Write-Output $msg.Body
$msg.Attachments.Add($att) 
$smtp.Send($msg)
}

Write-Host "DB Backup Script Completed"
