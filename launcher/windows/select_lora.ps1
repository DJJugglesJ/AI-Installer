param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "select_lora" -ScriptName "select_lora.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
