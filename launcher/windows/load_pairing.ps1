param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "load_pairing" -ScriptName "load_pairing_preset.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
