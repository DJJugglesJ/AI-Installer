param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "self_update" -ScriptName "self_update.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
