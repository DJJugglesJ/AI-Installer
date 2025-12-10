param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "install_sillytavern" -ScriptName "install_sillytavern.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
