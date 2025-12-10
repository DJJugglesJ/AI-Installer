param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "pair_oobabooga" -ScriptName "pair_oobabooga.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
