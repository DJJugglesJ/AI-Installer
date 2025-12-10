param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "manifest_browser" -ScriptName "manifest_browser.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
