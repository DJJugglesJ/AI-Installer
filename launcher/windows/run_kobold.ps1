param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_kobold" -ScriptName "run_kobold.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
