param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "install_models" -ScriptName "install_models.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
