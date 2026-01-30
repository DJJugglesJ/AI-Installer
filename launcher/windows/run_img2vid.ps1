param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

. "$PSScriptRoot/common.ps1"
$exitCode = Invoke-AIHubShellAction -ActionName "run_img2vid" -ScriptName "run_img2vid.sh" -AdditionalArgs $ExtraArgs
exit $exitCode
