param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "download_models_civitai" -ScriptName "install_models.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
