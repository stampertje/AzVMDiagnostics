[CmdletBinding()]
param (
    # provide subscription id
    [Parameter(Mandatory=$false)]
    [string]
    $AZSubscription = "3ea6e547-4e4f-45e3-94d3-267df1ab6e82", # MCAPS subscription

    # Name of the storage account
    [Parameter(Mandatory=$false)]
    [string]
    $storageAccount = "monitoringguest231416526",

    # Path to the diagnostics configuration file in json format
    [Parameter(Mandatory=$false)]
    [string]
    $diagnosticsconfig_path = "C:\Users\nicovan\OneDrive - Microsoft\Github\scripts\Azure\VMDiagnosticsConfig.json"

)

if ((get-azcontext).Subscription -ne $AZSubscription)
{
  Set-AzContext -Subscription $AZSubscription
}

$VMList = (Get-AzVM | Where-Object {$_.osprofile.WindowsConfiguration -ne $Null})

$sa = get-azstorageaccount | Where-Object {$_.StorageAccountname -ieq "$storageAccount"}

foreach ($vm in $VMList)
{
  Write-Host "Processing VM " $vm.Name -ForegroundColor Magenta

  if ($null -eq (Get-AzVMDiagnosticsExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.name))
  {
    $vmstate = (Get-AzVM -name $vm.name -status).PowerState
    $initialstate = $vmstate
    Write-Host "Powerstate is " $vmstate -ForegroundColor Yellow

    if ($vmstate -ine "VM Running")
    {
      Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
    }

    while ($vmstate -ine "VM Running")
    {
      Write-Host "Waiting for VM to start" -ForegroundColor Cyan
      Start-Sleep -Seconds 15
      $vmstate = (Get-AzVM -Name $vm.Name -status).PowerState
    }

    $vmname = $vm.Name
    $rgName = $vm.ResourceGroupName

    $DiagnosticsConfig = get-content $diagnosticsconfig_path | ConvertFrom-Json
    $DiagnosticsConfig.StorageAccount = $storageAccount
    $DiagnosticsConfig.WadCfg.DiagnosticMonitorConfiguration.Metrics.resourceId = $vm.id
    $DiagnosticsConfig | convertto-json -Depth 100 -compress | out-file "$env:temp\$vmname-diagnostics.json"

    try {
      Set-AzVMDiagnosticsExtension `
        -ResourceGroupName $rgName `
        -VMName $vmname `
        -DiagnosticsConfigurationPath $diagnosticsconfig_path `
        -StorageAccountName $storageAccount `
        -StorageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $sa.ResourceGroupName -AccountName $storageAccount).Value[0]
    } catch {
      exit
    }

    if ($initialstate -ine "VM Running")
    {
      write-host "Stopping vm" -ForegroundColor Cyan
      Stop-AzVM -ResourceGroupName $rgName -Name $vmname -Force
    }
  }
}