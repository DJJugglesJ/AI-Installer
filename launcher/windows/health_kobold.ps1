param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "health_kobold" -ScriptName "health_kobold.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
