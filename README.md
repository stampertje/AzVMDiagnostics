# Set-FDPO_AZvmDiagnosticLogging.ps1

This PowerShell script sets up diagnostic logging for Azure virtual machines.

## Parameters

- `AZSubscription` : The subscription ID to use.
- `storageAccount` : The name of the storage account to use.
- `diagnosticsconfig_path` : The path to the diagnostics configuration file in JSON format. Default value is "VMDiagnosticsConfig.json".
