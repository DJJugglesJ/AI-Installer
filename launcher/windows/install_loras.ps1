param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "install_loras" -ScriptName "install_loras.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
