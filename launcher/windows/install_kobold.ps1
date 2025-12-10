param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "install_kobold" -ScriptName "install_kobold.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
