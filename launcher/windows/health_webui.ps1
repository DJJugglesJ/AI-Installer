param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "health_webui" -ScriptName "health_webui.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
