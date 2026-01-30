param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_asr" -ScriptName "run_asr.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
