param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "artifact_manager" -ScriptName "artifact_manager.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
