param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "save_pairing_preset" -ScriptName "save_pairing_preset.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
