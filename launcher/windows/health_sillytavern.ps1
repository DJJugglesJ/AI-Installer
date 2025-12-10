param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "health_sillytavern" -ScriptName "health_sillytavern.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
