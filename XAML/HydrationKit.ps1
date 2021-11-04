#########################################################################
#                        Add shared_assemblies                          #
#########################################################################

[Void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 
foreach ($item in $(gci .\assembly\ -Filter *.dll).name) {
    [Void][System.Reflection.Assembly]::LoadFrom("assembly\$item")
}
Add-Type -AssemblyName System.Windows.Forms | Out-Null
Function New-Log {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )
	$logMessage = [System.Text.Encoding]::UTF8
    $timeStamp = Get-Date -Format "MM-dd-yyyy_HH:mm:ss"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $Global:pathLog 
}
#########################################################################
#                        Load Main Panel                                #
#########################################################################

$Global:pathPanel= split-path -parent $MyInvocation.MyCommand.Definition
function LoadXaml ($filename){
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}
$XamlMainWindow=LoadXaml("$Global:pathPanel\main.xaml")
$reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($reader)

$XamlMainWindow.SelectNodes("//*[@Name]") | %{
    try {Set-Variable -Name "$("WPF_"+$_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch{throw}
    }

Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
get-variable *WPF*
}
#Get-FormVariables

###################################################
#                    Variables                    #
###################################################
Function Parse-IniFile ($file) {
    $ini = @{}
  
    # Create a default section if none exist in the file. Like a java prop file.
    $section = "NO_SECTION"
    $ini[$section] = @{}
  
    switch -regex -file $file {
      "^\[(.+)\]$" {
        $section = $matches[1].Trim()
        $ini[$section] = @{}
      }
      "^\s*([^#].+?)\s*=\s*(.*)" {
        $name,$value = $matches[1..2]
        # skip comments that start with semicolon:
        if (!($name.StartsWith(";"))) {
          $ini[$section][$name] = $value.Trim()
        }
      }
    }
    $ini
}

function Out-IniFile($InputObject, $FilePath)
{
    $outFile = New-Item -ItemType file -Path $Filepath
    foreach ($i in $InputObject.keys)
    {
        if (!($($InputObject[$i].GetType().Name) -eq "Hashtable"))
        {
            #No Sections
            Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
        } else {
            #Sections
            Add-Content -Path $outFile -Value "[$i]"
            Foreach ($j in ($InputObject[$i].keys | Sort-Object))
            {
                if ($j -match "^Comment[\d]+") {
                    Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                } else {
                    Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])"
                }

            }
            Add-Content -Path $outFile -Value "" -Force
        }
    }
}

function New-MahappsMessage {
  [CmdletBinding()]
  param (
    
    [Parameter(Mandatory=$true)]
    [String]$title,
    [Parameter(Mandatory=$true)]
    [String]$Message
    
  )
  
  $Button_Style = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
  $okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::Affirmative  
  $result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,$title,$Message,$okAndCancel, $Button_Style)   
}

$WPF_Exit.Add_Click({
 # New-MahappsMessage -title "toto" -Message test

    exit
})
$WPF_Folder.Add_Click({

  $OpenFileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $OpenFileDialog.rootfolder = "MyComputer"
  [void]$OpenFileDialog.ShowDialog()
  $Script:Folder = $OpenFileDialog.SelectedPath

    # Test TS.ini file
    try {

      if ( (Test-Path  $Script:Folder\ISO\Content\Deploy\Control) -eq $True){
      $Script:TS = Get-ChildItem -Path $Script:Folder\ISO\Content\Deploy\Control -Name "CustomSettings_*.ini" 
      
      }
    }
    catch {
      
    }
  if ($null -eq $Script:TS) {

    }
    elseif ($Script:TS -ne $null) {
      $WPF_Go.Visibility = "Visible"
      $WPF_Backup.IsEnabled = $True
    } 

        # Test TS.Backup file
        try {

          if ( (Test-Path  $Script:Folder\ISO\Content\Deploy\Control) -eq $True){
          $Script:TSB = Get-ChildItem -Path $Script:Folder\ISO\Content\Deploy\Control -Filter *.backup
          
          }
        }
        catch {
          
        }
      if ($null -eq $Script:TS) {
    
        }
        elseif ($Script:TSB -ne $null) {
          $WPF_Backup.IsEnabled = $True
          $Script:CountTSB = $Script:TSB.count
        } 
})


$WPF_Go.Add_Click({

  [int]$Script:NbTS = $Script:TS.count

  $WPF_ActiveTS.Visibility = "Visible"
  $WPF_ActiveTS.Header = "DC01"
    
  if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DC01.ini ){
    $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DC01.ini
    $Script:GolbalFile = "CustomSettings_DC01.ini"
  }
  
  $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]
  
  $WPF_Computer_Name.Text             = $Script:FileTS.Default.HydrationOSDComputerName 
  $WPF_Local_Admin_PWD.Password     	= $Script:FileTS.Default.SafeModeAdminPassword
  $WPF_ADDS_Admin_PWD.Password        = $Script:FileTS.Default.SafeModeAdminPassword
  $WPF_ADDS_DRM_PWD.Password          = $Script:FileTS.Default.SafeModeAdminPassword
  $WPF_DHCP_DNS.Text                  = $Script:FileTS.Default.DHCPServerOptionDNSServer
  $WPF_DHCP_Domain_name.Text          = $Script:FileTS.Default.DHCPServerOptionDNSDomainName
  $WPF_DHCP_EndIP.Text                = $Script:FileTS.Default.DHCPScopes0EndIP
  $WPF_DHCP_Name.Text                 = $Script:FileTS.Default.DHCPScopes0Name
  $WPF_DHCP_Routeur.Text              = $Script:FileTS.Default.DHCPServerOptionRouter
  $WPF_DHCP_Scope.Text                = $Script:FileTS.Default.DHCPScopes0IP
  $WPF_DHCP_StartIP.Text              = $Script:FileTS.Default.DHCPScopes0StartIP
  $WPF_DNS_Server.Text                = $Script:FileTS.Default.OSDAdapter0DNSServerList
  $WPF_Domain_DNS_Name.Text           = $Script:FileTS.Default.NewDomainDNSName
  $WPF_Domain_NetBios_Name.Text       = $Script:FileTS.Default.DomainNetBiosName
  $WPF_Gateway.Text                   = $Script:FileTS.Default.OSDAdapter0Gateways
  $WPF_IPAddress.Text                 = $Script:FileTS.Default.OSDAdapter0IPAddressList
  $WPF_Site_Name.Text                 = $Script:FileTS.Default.SiteName
  $WPF_SubnetMask.Text 	              = $Script:FileTS.Default.OSDAdapter0SubnetMask
  $WPF_UserName.Text                  = $Script:FileTS.Default.DomainAdmin
  
  $WPF_ADDS_Admin_PWD.IsEnabled = $false
  $WPF_ADDS_DRM_PWD.IsEnabled = $False
  $WPF_UserName.IsEnabled = $False
  

})
$WPF_Next.Add_Click({
    
  [int]$Script:NbTS = [int]$Script:NbTS - 1
  try {
    $WPF_Curent_Change.IsEnabled = $true
    }
  catch {
    
  }
  switch ([int]$Script:NbTS) {

    4 {
      $WPF_STk_ADP.Visibility = "Collapsed"
      $WPF_STk_DAD.Visibility = "Visible"
      $WPF_STk_DAP.Visibility = "Collapsed"
      $WPF_STk_DDN.Visibility = "Collapsed"
      $WPF_STk_DDNN.Visibility = "Collapsed"
      $WPF_STk_SN.Visibility = "Collapsed"
      $WPF_STk_DS.Visibility = "Collapsed"
      $WPF_STk_JD.Visibility = "Visible"
      $WPF_STk_MO.Visibility = "Visible"

      $WPF_STk_Domain_Wrk.Visibility = "Collapsed"
      $WPF_ActiveTS.Header = "CM01"
      $WPF_title.Text = "Settings - CM01"
      if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_CM01.ini ){
        $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_CM01.ini
        $Script:GolbalFile = "CustomSettings_CM01.ini"
      }
      
      $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]
      
      $WPF_Computer_Name.Text             = $Script:FileTS.Default.HydrationOSDComputerName 
      $WPF_Local_Admin_PWD.Password     	= $Script:FileTS.Default.DomainAdminPassword
      $WPF_DNS_Server.Text                = $Script:FileTS.Default.OSDAdapter0DNSServerList
      $WPF_Domain_DNS_Name.Text           = $Script:FileTS.Default.NewDomainDNSName
      $WPF_Domain_NetBios_Name.Text       = $Script:FileTS.Default.DomainNetBiosName
      $WPF_Gateway.Text                   = $Script:FileTS.Default.OSDAdapter0Gateways
      $WPF_IPAddress.Text                 = $Script:FileTS.Default.OSDAdapter0IPAddressList
      $WPF_SubnetMask.Text 	              = $Script:FileTS.Default.OSDAdapter0SubnetMask
      $WPF_UserName.Text                  = $Script:FileTS.Default.DomainAdmin
      $WPF_Join_Domain.Text               = $Script:FileTS.Default.JoinDomain
      $WPF_Machine_OU.Text                = $Script:FileTS.Default.MachineObjectOU
      $WPF_DomainAdminDomain.Text         = $Script:FileTS.Default.DomainAdminDomain
      }
    3 {
      $WPF_ActiveTS.Header = "DP01"
      $WPF_title.Text = "Settings - DP01"
      if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DP01.ini ){
        $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DP01.ini
        $Script:GolbalFile = "CustomSettings_DP01.ini"
      }
      
      $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]
      
      $WPF_Computer_Name.Text             = $Script:FileTS.Default.HydrationOSDComputerName 
      $WPF_Local_Admin_PWD.Password     	= $Script:FileTS.Default.DomainAdminPassword
      $WPF_DNS_Server.Text                = $Script:FileTS.Default.OSDAdapter0DNSServerList
      $WPF_Domain_DNS_Name.Text           = $Script:FileTS.Default.NewDomainDNSName
      $WPF_Domain_NetBios_Name.Text       = $Script:FileTS.Default.DomainNetBiosName
      $WPF_Gateway.Text                   = $Script:FileTS.Default.OSDAdapter0Gateways
      $WPF_IPAddress.Text                 = $Script:FileTS.Default.OSDAdapter0IPAddressList
      $WPF_SubnetMask.Text 	              = $Script:FileTS.Default.OSDAdapter0SubnetMask
      $WPF_UserName.Text                  = $Script:FileTS.Default.DomainAdmin
      $WPF_Join_Domain.Text               = $Script:FileTS.Default.JoinDomain
      $WPF_Machine_OU.Text                = $Script:FileTS.Default.MachineObjectOU
      $WPF_DomainAdminDomain.Text         = $Script:FileTS.Default.DomainAdminDomain

      }
    2 {
        $WPF_ActiveTS.Header = "FS01"
        $WPF_title.Text = "Settings - FS01"
        if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_FS01.ini ){
          $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_FS01.ini
          $Script:GolbalFile = "CustomSettings_FS01.ini"
        }
        
        $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]
        
        $WPF_Computer_Name.Text             = $Script:FileTS.Default.HydrationOSDComputerName 
        $WPF_Local_Admin_PWD.Password     	= $Script:FileTS.Default.DomainAdminPassword
        $WPF_DNS_Server.Text                = $Script:FileTS.Default.OSDAdapter0DNSServerList
        $WPF_Domain_DNS_Name.Text           = $Script:FileTS.Default.NewDomainDNSName
        $WPF_Domain_NetBios_Name.Text       = $Script:FileTS.Default.DomainNetBiosName
        $WPF_Gateway.Text                   = $Script:FileTS.Default.OSDAdapter0Gateways
        $WPF_IPAddress.Text                 = $Script:FileTS.Default.OSDAdapter0IPAddressList
        $WPF_SubnetMask.Text 	              = $Script:FileTS.Default.OSDAdapter0SubnetMask
        $WPF_UserName.Text                  = $Script:FileTS.Default.DomainAdmin
        $WPF_Join_Domain.Text               = $Script:FileTS.Default.JoinDomain
        $WPF_Machine_OU.Text                = $Script:FileTS.Default.MachineObjectOU
        $WPF_DomainAdminDomain.Text         = $Script:FileTS.Default.DomainAdminDomain
  
      }
    1 {
        $WPF_ActiveTS.Header = "MDT01"
        $WPF_title.Text = "Settings - MDT01"
        if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_MDT01.ini ){
          $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_MDT01.ini
          $Script:GolbalFile = "CustomSettings_MDT01.ini"
        }
        
        $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]
        
        $WPF_Computer_Name.Text             = $Script:FileTS.Default.HydrationOSDComputerName 
        $WPF_Local_Admin_PWD.Password     	= $Script:FileTS.Default.DomainAdminPassword
        $WPF_DNS_Server.Text                = $Script:FileTS.Default.OSDAdapter0DNSServerList
        $WPF_Domain_DNS_Name.Text           = $Script:FileTS.Default.NewDomainDNSName
        $WPF_Domain_NetBios_Name.Text       = $Script:FileTS.Default.DomainNetBiosName
        $WPF_Gateway.Text                   = $Script:FileTS.Default.OSDAdapter0Gateways
        $WPF_IPAddress.Text                 = $Script:FileTS.Default.OSDAdapter0IPAddressList
        $WPF_SubnetMask.Text 	              = $Script:FileTS.Default.OSDAdapter0SubnetMask
        $WPF_UserName.Text                  = $Script:FileTS.Default.DomainAdmin
        $WPF_Join_Domain.Text               = $Script:FileTS.Default.JoinDomain
        $WPF_Machine_OU.Text                = $Script:FileTS.Default.MachineObjectOU
        $WPF_DomainAdminDomain.Text         = $Script:FileTS.Default.DomainAdminDomain
        $WPF_Next.Content = "Last"
        $WPF_Next.IsEnabled = $false
      }
    Default { }
  }

})

$WPF_Curent_Change.Add_Click({

  switch ([int]$Script:NbTS) {
    99{
        $Script:FileTS.Default._SMSTSORGNAME        = $WPF__SMSTSORGNAME.Text         
        $Script:FileTS.Default.OrgName              = $WPF_OrgName.Text                
        $Script:FileTS.Default.TimeZoneName         = $WPF_TimeZoneName.Text           
        $Script:FileTS.Default.AdminPassword        = $WPF_Admin_PWD.Password       	
        $Script:FileTS.Default.SkipAdminPassword    = $WPF_SkipAdminPassword.Text     
        $Script:FileTS.Default.SkipApplications     = $WPF_SkipApplications.Text       
        $Script:FileTS.Default.SkipBitLocker        = $WPF_SkipBitLocker.Text          
        $Script:FileTS.Default.SkipCapture          = $WPF_SkipCapture.Text            
        $Script:FileTS.Default.SkipComputerName     = $WPF_SkipComputerName.Text       
        $Script:FileTS.Default.SkipDomainMembership = $WPF_SkipDomainMembership.Text   
        $Script:FileTS.Default.SkipFinalSummary     = $WPF_SkipFinalSummary.Text      
        $Script:FileTS.Default.SkipLocaleSelection  = $WPF_SkipLocaleSelection.Text   
        $Script:FileTS.Default.SkipProductKey       = $WPF_SkipProductKey.Text       
        $Script:FileTS.Default.SkipSummary          = $WPF_SkipSummary.Text           
        $Script:FileTS.Default.SkipTaskSequence     = $WPF_SkipTaskSequence.Text      
        $Script:FileTS.Default.SkipTimeZone         = $WPF_SkipTimeZone.Text          
        $Script:FileTS.Default.SkipUserData         = $WPF_SkipUserData.Text          
        $Script:FileTS.Default.SkipRoles            = $WPF_SkipRoles.Text             

        if($WPF_KMS.SelectedIndex = 0){

          $Script:FileTS.Default.ProductKey = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"
        }elseif ( $WPF_KMS.SelectedIndex = 1) {
          $Script:FileTS.Default.ProductKey = "N69G4-B89J2-4G8F4-WWYCC-J464C"
        }
        else {
          $Script:FileTS.Default.ProductKey = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"
        }

        Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings.ini.backup
        Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettingsM.ini
        $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettingsM.ini
        $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings.ini -Force
        Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettingsM.ini -Force | Out-Null

        $WPF__SMSTSORGNAME.Text         =""        
        $WPF_OrgName.Text               =""
        $WPF_TimeZoneName.Text          =""
        $WPF_Admin_PWD.Password       	=""
        $WPF_SkipAdminPassword.Text     =""
        $WPF_SkipApplications.Text      =""
        $WPF_SkipBitLocker.Text         =""
        $WPF_SkipCapture.Text           =""
        $WPF_SkipComputerName.Text      =""
        $WPF_SkipDomainMembership.Text  =""
        $WPF_SkipFinalSummary.Text      =""
        $WPF_SkipLocaleSelection.Text   =""
        $WPF_SkipProductKey.Text        =""
        $WPF_SkipSummary.Text           =""
        $WPF_SkipTaskSequence.Text      =""
        $WPF_SkipTimeZone.Text          =""
        $WPF_SkipUserData.Text          =""
        $WPF_SkipRoles.Text             =""
        
        $WPF_STK_Last.Visibility = "Hidden"
        $WPF_Curent_Change.Visibility = "Hidden"
        $WPF_Next.Visibility = "Hidden"
        $WPF_LastC.Visibility = "Hidden"
        $WPF_STk_Final.Visibility = "Visible"
      }
    5 {   
      $Script:FileTS.Default.HydrationOSDComputerName         = $WPF_Computer_Name.Text             
      $Script:FileTS.Default.SafeModeAdminPassword            = $WPF_Local_Admin_PWD.Password     
      $Script:FileTS.Default.SafeModeAdminPassword            = $WPF_ADDS_Admin_PWD.Password       
      $Script:FileTS.Default.SafeModeAdminPassword            = $WPF_ADDS_DRM_PWD.Password         
      $Script:FileTS.Default.DHCPServerOptionDNSServer        = $WPF_DHCP_DNS.Text 
      $Script:FileTS.Default.DHCPServerOptionDNSDomainName    = $WPF_DHCP_Domain_name.Text   
      $Script:FileTS.Default.DHCPScopes0EndIP                 = $WPF_DHCP_EndIP.Text
      $Script:FileTS.Default.DHCPScopes0Name                  = $WPF_DHCP_Name.Text 
      $Script:FileTS.Default.DHCPServerOptionRouter           = $WPF_DHCP_Routeur.Text  
      $Script:FileTS.Default.DHCPScopes0IP                    = $WPF_DHCP_Scope.Text  
      $Script:FileTS.Default.DHCPScopes0StartIP               = $WPF_DHCP_StartIP.Text
      $Script:FileTS.Default.OSDAdapter0DNSServerList         = $WPF_DNS_Server.Text  
      $Script:FileTS.Default.NewDomainDNSName                 = $WPF_Domain_DNS_Name.Text 
      $Script:FileTS.Default.DomainNetBiosName                = $WPF_Domain_NetBios_Name.Text    
      $Script:FileTS.Default.OSDAdapter0Gateways              = $WPF_Gateway.Text  
      $Script:FileTS.Default.OSDAdapter0IPAddressList         = $WPF_IPAddress.Text            
      $Script:FileTS.Default.SiteName                         = $WPF_Site_Name.Text                 
      $Script:FileTS.Default.OSDAdapter0SubnetMask            = $WPF_SubnetMask.Text 	             
      $Script:FileTS.Default.DomainAdmin                      = $WPF_UserName.Text     
      
      Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DC01.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DC01.ini.backup
      Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DC01M.ini
      $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettings_DC01M.ini
      $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings_DC01.ini -Force
      Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettings_DC01M.ini -Force | Out-Null
       
      $WPF_Curent_Change.IsEnabled = $false
    
      $WPF_Computer_Name.Text           = ""      
      $WPF_Local_Admin_PWD.Password     = ""  	
      $WPF_ADDS_Admin_PWD.Password      = ""  
      $WPF_ADDS_DRM_PWD.Password        = ""  
      $WPF_DHCP_DNS.Text                = ""  
      $WPF_DHCP_Domain_name.Text        = ""  
      $WPF_DHCP_EndIP.Text              = ""  
      $WPF_DHCP_Name.Text               = ""  
      $WPF_DHCP_Routeur.Text            = ""  
      $WPF_DHCP_Scope.Text              = ""  
      $WPF_DHCP_StartIP.Text            = ""  
      $WPF_DNS_Server.Text              = ""  
      $WPF_Domain_DNS_Name.Text         = ""  
      $WPF_Domain_NetBios_Name.Text     = ""  
      $WPF_Gateway.Text                 = ""  
      $WPF_IPAddress.Text               = ""  
      $WPF_Site_Name.Text               = ""  
      $WPF_SubnetMask.Text 	            = ""  
      $WPF_UserName.Text                = ""  
      }
    4 {

      $Script:FileTS.Default.HydrationOSDComputerName  = $WPF_Computer_Name.Text             
      $Script:FileTS.Default.DomainAdminPassword = $WPF_Local_Admin_PWD.Password   
      $Script:FileTS.Default.OSDAdapter0DNSServerList =$WPF_DNS_Server.Text 
      $Script:FileTS.Default.NewDomainDNSName =$WPF_Domain_DNS_Name.Text 
      $Script:FileTS.Default.DomainNetBiosName = $WPF_Domain_NetBios_Name.Text 
      $Script:FileTS.Default.OSDAdapter0Gateways = $WPF_Gateway.Text 
      $Script:FileTS.Default.OSDAdapter0IPAddressList = $WPF_IPAddress.Text 
      $Script:FileTS.Default.OSDAdapter0SubnetMask = $WPF_SubnetMask.Text
      $Script:FileTS.Default.DomainAdmin = $WPF_UserName.Text 
      $Script:FileTS.Default.JoinDomain = $WPF_Join_Domain.Text 
      $Script:FileTS.Default.MachineObjectOU = $WPF_Machine_OU.Text 
      $Script:FileTS.Default.DomainAdminDomain = $WPF_DomainAdminDomain.Text 
      
      Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_CM01.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_CM01.ini.backup
      Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_CM01M.ini
      $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettings_CM01M.ini
      $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings_CM01.ini -Force
      Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettings_CM01M.ini -Force | Out-Null
    
      $WPF_Curent_Change.IsEnabled = $false

      $WPF_Computer_Name.Text            =""
      $WPF_Local_Admin_PWD.Password      =""	
      $WPF_DNS_Server.Text               ="" 
      $WPF_Domain_DNS_Name.Text          =""  
      $WPF_Domain_NetBios_Name.Text      =""
      $WPF_Gateway.Text                  ="" 
      $WPF_IPAddress.Text                ="" 
      $WPF_SubnetMask.Text 	             ="" 
      $WPF_UserName.Text                 ="" 
      $WPF_Join_Domain.Text              ="" 
      $WPF_Machine_OU.Text               ="" 
      $WPF_DomainAdminDomain.Text        =""


      }
    3 {

        $Script:FileTS.Default.HydrationOSDComputerName  = $WPF_Computer_Name.Text             
        $Script:FileTS.Default.DomainAdminPassword = $WPF_Local_Admin_PWD.Password   
        $Script:FileTS.Default.OSDAdapter0DNSServerList =$WPF_DNS_Server.Text 
        $Script:FileTS.Default.NewDomainDNSName =$WPF_Domain_DNS_Name.Text 
        $Script:FileTS.Default.DomainNetBiosName = $WPF_Domain_NetBios_Name.Text 
        $Script:FileTS.Default.OSDAdapter0Gateways = $WPF_Gateway.Text 
        $Script:FileTS.Default.OSDAdapter0IPAddressList = $WPF_IPAddress.Text 
        $Script:FileTS.Default.OSDAdapter0SubnetMask = $WPF_SubnetMask.Text
        $Script:FileTS.Default.DomainAdmin = $WPF_UserName.Text 
        $Script:FileTS.Default.JoinDomain = $WPF_Join_Domain.Text 
        $Script:FileTS.Default.MachineObjectOU = $WPF_Machine_OU.Text 
        $Script:FileTS.Default.DomainAdminDomain = $WPF_DomainAdminDomain.Text 
        
        Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DP01.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DP01.ini.backup
        Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_DP01M.ini
        $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettings_DP01M.ini
        $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings_DP01.ini -Force
        Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettings_DP01M.ini -Force | Out-Null
      
        $WPF_Curent_Change.IsEnabled = $false
  
        $WPF_Computer_Name.Text            =""
        $WPF_Local_Admin_PWD.Password      =""	
        $WPF_DNS_Server.Text               ="" 
        $WPF_Domain_DNS_Name.Text          =""  
        $WPF_Domain_NetBios_Name.Text      =""
        $WPF_Gateway.Text                  ="" 
        $WPF_IPAddress.Text                ="" 
        $WPF_SubnetMask.Text 	             ="" 
        $WPF_UserName.Text                 ="" 
        $WPF_Join_Domain.Text              ="" 
        $WPF_Machine_OU.Text               ="" 
        $WPF_DomainAdminDomain.Text        =""
      }
    2 {

        $Script:FileTS.Default.HydrationOSDComputerName  = $WPF_Computer_Name.Text             
        $Script:FileTS.Default.DomainAdminPassword = $WPF_Local_Admin_PWD.Password   
        $Script:FileTS.Default.OSDAdapter0DNSServerList =$WPF_DNS_Server.Text 
        $Script:FileTS.Default.NewDomainDNSName =$WPF_Domain_DNS_Name.Text 
        $Script:FileTS.Default.DomainNetBiosName = $WPF_Domain_NetBios_Name.Text 
        $Script:FileTS.Default.OSDAdapter0Gateways = $WPF_Gateway.Text 
        $Script:FileTS.Default.OSDAdapter0IPAddressList = $WPF_IPAddress.Text 
        $Script:FileTS.Default.OSDAdapter0SubnetMask = $WPF_SubnetMask.Text
        $Script:FileTS.Default.DomainAdmin = $WPF_UserName.Text 
        $Script:FileTS.Default.JoinDomain = $WPF_Join_Domain.Text 
        $Script:FileTS.Default.MachineObjectOU = $WPF_Machine_OU.Text 
        $Script:FileTS.Default.DomainAdminDomain = $WPF_DomainAdminDomain.Text 
        
        Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_FS01.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_FS01.ini.backup
        Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_FS01M.ini
        $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettings_FS01M.ini
        $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings_FS01.ini -Force
        Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettings_FS01M.ini -Force | Out-Null
      
        $WPF_Curent_Change.IsEnabled = $false
  
        $WPF_Computer_Name.Text            =""
        $WPF_Local_Admin_PWD.Password      =""	
        $WPF_DNS_Server.Text               ="" 
        $WPF_Domain_DNS_Name.Text          =""  
        $WPF_Domain_NetBios_Name.Text      =""
        $WPF_Gateway.Text                  ="" 
        $WPF_IPAddress.Text                ="" 
        $WPF_SubnetMask.Text 	             ="" 
        $WPF_UserName.Text                 ="" 
        $WPF_Join_Domain.Text              ="" 
        $WPF_Machine_OU.Text               ="" 
        $WPF_DomainAdminDomain.Text        =""
      }
    1 {
        $Script:FileTS.Default.HydrationOSDComputerName  = $WPF_Computer_Name.Text             
        $Script:FileTS.Default.DomainAdminPassword = $WPF_Local_Admin_PWD.Password   
        $Script:FileTS.Default.OSDAdapter0DNSServerList =$WPF_DNS_Server.Text 
        $Script:FileTS.Default.NewDomainDNSName =$WPF_Domain_DNS_Name.Text 
        $Script:FileTS.Default.DomainNetBiosName = $WPF_Domain_NetBios_Name.Text 
        $Script:FileTS.Default.OSDAdapter0Gateways = $WPF_Gateway.Text 
        $Script:FileTS.Default.OSDAdapter0IPAddressList = $WPF_IPAddress.Text 
        $Script:FileTS.Default.OSDAdapter0SubnetMask = $WPF_SubnetMask.Text
        $Script:FileTS.Default.DomainAdmin = $WPF_UserName.Text 
        $Script:FileTS.Default.JoinDomain = $WPF_Join_Domain.Text 
        $Script:FileTS.Default.MachineObjectOU = $WPF_Machine_OU.Text 
        $Script:FileTS.Default.DomainAdminDomain = $WPF_DomainAdminDomain.Text 
        
        Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_MDT01.ini -Destination $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_MDT01.ini.backup
        Out-IniFile $Script:FileTS  $Script:Folder\ISO\Content\Deploy\Control\CustomSettings_MDT01M.ini
        $File = Get-Content C:\Test\ISO\Content\Deploy\Control\CustomSettings_MDT01M.ini
        $File.Replace("[NO_SECTION]","") | Set-Content  C:\Test\ISO\Content\Deploy\Control\CustomSettings_MDT01.ini -Force
        Remove-Item C:\Test\ISO\Content\Deploy\Control\CustomSettings_MDT01M.ini -Force | Out-Null
      
        $WPF_Curent_Change.IsEnabled = $false
  
        $WPF_Computer_Name.Text            =""
        $WPF_Local_Admin_PWD.Password      =""	
        $WPF_DNS_Server.Text               ="" 
        $WPF_Domain_DNS_Name.Text          =""  
        $WPF_Domain_NetBios_Name.Text      =""
        $WPF_Gateway.Text                  ="" 
        $WPF_IPAddress.Text                ="" 
        $WPF_SubnetMask.Text 	             ="" 
        $WPF_UserName.Text                 ="" 
        $WPF_Join_Domain.Text              ="" 
        $WPF_Machine_OU.Text               ="" 
        $WPF_DomainAdminDomain.Text        =""
        $WPF_Next.Content = "Last"
        $WPF_Next.IsEnabled = $false
        $WPF_LastC.Visibility = "Visible"
        $WPF_Curent_Change.IsEnabled = $true
      }
   
    Default {}
  }


})

$WPF_KMS.Add_SelectionChanged({

  $SelectedItem = $WPF_KMS.SelectedItem.Name

    switch ($SelectedItem) {
      'WC2BQ' { $WPF_KMSKey.Content = 'Windows Server 2016 STD'  }
      'N69G4' { $WPF_KMSKey.Content = 'Windows Server 2019 STD'}
      'VDYBN' {$WPF_KMSKey.Content = 'Windows Server 2022 STD'}
      Default {}
    }
})

$WPF_Backup.Add_Click({

  try {

    if ( (Test-Path  $Script:Folder\ISO\Content\Deploy\Control) -eq $True){
    $Script:TSB = Get-ChildItem -Path $Script:Folder\ISO\Content\Deploy\Control -Filter *.backup
    
    }
  }
  catch {
    
  }
if ($null -eq $Script:TS) {

  }
  elseif ($Script:TSB -ne $null) {
    $WPF_Backup.IsEnabled = $True
    $Script:CountTSB = $Script:TSB.count
  } 

  New-MahappsMessage -title Information -Message "We found $CountTSB backup Files. I will restore all backup found"

  foreach ($files in $Script:TSB.Name){

    $newname = $files.Split(".")[0] + "." + $files.Split(".")[1]

    Copy-Item -Path $Script:Folder\ISO\Content\Deploy\Control\$files -Destination $Script:Folder\ISO\Content\Deploy\Control\$newname -Force | Out-Null
    Remove-Item -Path $Script:Folder\ISO\Content\Deploy\Control\$files -Force | Out-Null
  }
})

$WPF_LastC.Add_Click({

  [Int]$Script:NbTS = 99
  $WPF_ActiveTS.Header = "CustomSettings"
  $WPF_title.Text = "Default Settings for HydrationKit"
  if (Test-Path $Script:Folder\ISO\Content\Deploy\Control\CustomSettings.ini ){
    $Script:FileTS = Parse-IniFile $Script:Folder\ISO\Content\Deploy\Control\CustomSettings.ini
    $Script:GolbalFile = "CustomSettings.ini"
  }
  $WPF_STk_Full.Visibility = "Collapsed"
  $WPF_STk_Last.Visibility = "Visible"
  $WPF_Tabcontrol.selecteditem = $WPF_Tabcontrol.Items[1]

  $WPF__SMSTSORGNAME.Text         = $Script:FileTS.Default._SMSTSORGNAME
  $WPF_OrgName.Text               = $Script:FileTS.Default.OrgName
  $WPF_TimeZoneName.Text          = $Script:FileTS.Default.TimeZoneName
  $WPF_Admin_PWD.Password       	= $Script:FileTS.Default.AdminPassword
  $WPF_SkipAdminPassword.Text     = $Script:FileTS.Default.SkipAdminPassword
  $WPF_SkipApplications.Text      = $Script:FileTS.Default.SkipApplications
  $WPF_SkipBitLocker.Text         = $Script:FileTS.Default.SkipBitLocker
  $WPF_SkipCapture.Text           = $Script:FileTS.Default.SkipCapture
  $WPF_SkipComputerName.Text      = $Script:FileTS.Default.SkipComputerName
  $WPF_SkipDomainMembership.Text  = $Script:FileTS.Default.SkipDomainMembership
  $WPF_SkipFinalSummary.Text      = $Script:FileTS.Default.SkipFinalSummary
  $WPF_SkipLocaleSelection.Text   = $Script:FileTS.Default.SkipLocaleSelection
  $WPF_SkipProductKey.Text       = $Script:FileTS.Default.SkipProductKey
  $WPF_SkipSummary.Text           = $Script:FileTS.Default.SkipSummary
  $WPF_SkipTaskSequence.Text      = $Script:FileTS.Default.SkipTaskSequence
  $WPF_SkipTimeZone.Text          = $Script:FileTS.Default.SkipTimeZone
  $WPF_SkipUserData.Text          = $Script:FileTS.Default.SkipUserData
  $WPF_SkipRoles.Text             = $Script:FileTS.Default.SkipRoles

  if ($Script:FileTS.Default.ProductKey -eq "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"  ) {

    $WPF_KMS.SelectedIndex = 0
    
  }elseif ($Script:FileTS.Default.ProductKey -eq "N69G4-B89J2-4G8F4-WWYCC-J464C") {
    $WPF_KMS.SelectedIndex = 1
  }
  else{
    $WPF_KMS.SelectedIndex = 2
  }


})

$Form.ShowDialog() | Out-Null