

 $file = gci -Path C:\Test\ISO\Content\Deploy\Control -Filter *.backup

foreach ($files in $file.Name){

  $newname = $files.Split(".")[0] + "." + $files.Split(".")[1]

  Write-Host $newname

}

C:\Users\JM2K69\Downloads\HydrationCMWS2019\HydrationCMWS2019_Setup\Source\Hydration\Control


$NewDomainNamefiles=Get-ChildItem -recurse -Path c:\test\DS | Select-String -pattern 'VIAMONSTRA' | group path | select name


foreach($NewDomainNamefile in $NewDomainNamefiles.Name)
{ 
    Write-Host "$NewDomainNamefile "
    (Get-Content $NewDomainNamefile).replace('VIAMONSTRA', 'JM2K69') | Set-Content $NewDomainNamefile
    pause
}

(Get-Content -Path 'C:\Test\DS\Applications\Install - ConfigMgr\ConfigMgrUnattend.ini').replace('corp.viamonstra.com', 'jm2K69.loc')|Set-Content 'C:\Test\DS\Applications\Install - ConfigMgr\ConfigMgrUnattendL.ini'