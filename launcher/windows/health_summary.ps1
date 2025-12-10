param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "health_summary" -ScriptName "health_summary.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
