param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "pair_sillytavern" -ScriptName "pair_sillytavern.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
