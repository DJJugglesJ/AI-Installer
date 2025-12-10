param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_sillytavern" -ScriptName "run_sillytavern.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
