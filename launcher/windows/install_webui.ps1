param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "install_webui" -ScriptName "install_webui.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
