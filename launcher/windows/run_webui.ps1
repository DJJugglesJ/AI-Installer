param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_webui" -ScriptName "run_webui.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
