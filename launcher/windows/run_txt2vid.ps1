param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_txt2vid" -ScriptName "run_txt2vid.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
