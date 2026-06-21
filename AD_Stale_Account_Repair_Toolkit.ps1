[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Identity,
    [ValidateSet('User','Computer')][string]$ObjectType='User',
    [switch]$DisableAccount,
    [string]$MoveToOU,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$LogDirectory="$env:ProgramData\IAmLegionVaal\ADStaleAccountRepair"
)

$ErrorActionPreference='Stop'
$ExitInvalidInput=2; $ExitPrerequisite=3; $ExitCancelled=4; $ExitActionFailure=5; $ExitVerificationFailure=6
function Test-Admin {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Write-Log([string]$Message){$line="{0:u} {1}" -f (Get-Date),$Message;Write-Host $line;Add-Content -LiteralPath $script:LogPath -Value $line}
function Invoke-Step([string]$Description,[scriptblock]$Action){if($DryRun){Write-Log "[DRY-RUN] $Description"}else{Write-Log "[ACTION] $Description";& $Action}}

if(-not($DisableAccount -or -not [string]::IsNullOrWhiteSpace($MoveToOU))){Write-Error 'Select -DisableAccount, -MoveToOU, or both.';exit $ExitInvalidInput}
if(-not(Test-Admin)){Write-Error 'Run from an elevated PowerShell session.';exit $ExitPrerequisite}
try{Import-Module ActiveDirectory -ErrorAction Stop}catch{Write-Error "ActiveDirectory module unavailable: $($_.Exception.Message)";exit $ExitPrerequisite}

New-Item -ItemType Directory -Path $LogDirectory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$script:LogPath=Join-Path $LogDirectory "ADStaleAccountRepair_$stamp.log";$backupPath=Join-Path $LogDirectory "StaleAccount_$stamp.xml"
try{
    if($ObjectType -eq 'User'){$target=Get-ADUser -Identity $Identity -Properties Enabled,AdminCount,LastLogonDate,PasswordLastSet,DistinguishedName}
    else{$target=Get-ADComputer -Identity $Identity -Properties Enabled,AdminCount,PrimaryGroupID,LastLogonDate,PasswordLastSet,OperatingSystem,DistinguishedName}
    if($MoveToOU){$ou=Get-ADOrganizationalUnit -Identity $MoveToOU}
}catch{Write-Error "Unable to resolve the selected object or destination OU: $($_.Exception.Message)";exit $ExitInvalidInput}
if($target.AdminCount -eq 1){Write-Error 'Protected administrative objects are excluded from automated stale-account repair.';exit $ExitInvalidInput}
if($ObjectType -eq 'Computer' -and ($target.PrimaryGroupID -eq 516 -or $target.DistinguishedName -match '(?i)OU=Domain Controllers')){Write-Error 'Domain controllers are excluded from automated stale-account repair.';exit $ExitInvalidInput}
if($ObjectType -eq 'User' -and $target.SamAccountName -ieq $env:USERNAME){Write-Error 'The current signed-in account is excluded from stale-account repair.';exit $ExitInvalidInput}
[pscustomobject]@{Target=$target;DestinationOU=$ou}|Export-Clixml -LiteralPath $backupPath
Write-Log "Saved pre-change object evidence to $backupPath"

$actions=@();if($DisableAccount){$actions+='disable account'};if($MoveToOU){$actions+="move to $($ou.DistinguishedName)"}
if(-not $DryRun -and -not $Yes){$answer=Read-Host ("Proceed for {0} {1}: {2}? [y/N]" -f $ObjectType,$Identity,($actions -join '; '));if($answer -notmatch '^(?i)y(es)?$'){Write-Log '[CANCELLED] No changes were made.';exit $ExitCancelled}}

try{
    if($DisableAccount){Invoke-Step "Disable $ObjectType '$Identity'" {Disable-ADAccount -Identity $target.DistinguishedName}}
    if($MoveToOU){Invoke-Step "Move $ObjectType '$Identity' to '$($ou.DistinguishedName)'" {Move-ADObject -Identity $target.DistinguishedName -TargetPath $ou.DistinguishedName}}
}catch{Write-Log "[FAILED] $($_.Exception.Message)";exit $ExitActionFailure}
if($DryRun){Write-Log '[COMPLETE] Dry-run completed.';exit 0}

$verifyFailed=$false
try{
    if($ObjectType -eq 'User'){$after=Get-ADUser -Identity $target.ObjectGUID -Properties Enabled,DistinguishedName}
    else{$after=Get-ADComputer -Identity $target.ObjectGUID -Properties Enabled,DistinguishedName}
    Write-Log ("[VERIFY] Enabled={0}; DistinguishedName={1}" -f $after.Enabled,$after.DistinguishedName)
    if($DisableAccount -and $after.Enabled){$verifyFailed=$true}
    if($MoveToOU -and $after.DistinguishedName -notlike "*,$($ou.DistinguishedName)"){$verifyFailed=$true}
}catch{Write-Log "[VERIFY-FAILED] $($_.Exception.Message)";$verifyFailed=$true}
if($verifyFailed){exit $ExitVerificationFailure}
Write-Log '[COMPLETE] Stale-account repair and verification completed.'
exit 0
