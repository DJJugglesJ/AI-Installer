param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_tts" -ScriptName "run_tts.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
