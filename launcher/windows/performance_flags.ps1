param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "performance_flags" -ScriptName "performance_flags.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
