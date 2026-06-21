# AD Stale Account Risk Reporter

A PowerShell toolkit for reporting stale Active Directory users and computers and applying selected, guarded account-retirement actions.

## Repair

Preview a stale-user disablement:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Stale_Account_Repair_Toolkit.ps1 -Identity olduser -ObjectType User -DisableAccount -DryRun
```

Examples:

```powershell
.\AD_Stale_Account_Repair_Toolkit.ps1 -Identity olduser -DisableAccount
.\AD_Stale_Account_Repair_Toolkit.ps1 -Identity PC-OLD-01 -ObjectType Computer -DisableAccount
.\AD_Stale_Account_Repair_Toolkit.ps1 -Identity olduser -DisableAccount -MoveToOU 'OU=Quarantine,DC=contoso,DC=com'
```

## Repair behavior

- Requires elevation, domain connectivity and the RSAT Active Directory module.
- Modifies only one explicitly selected user or computer per run.
- Can disable the selected account, move it to an explicitly selected OU, or perform both actions.
- Saves the target object and destination-OU evidence to CLIXML before modification.
- Refuses protected administrative objects, domain controllers and the current signed-in user.
- Supports `-DryRun`, confirmation or `-Yes`, timestamped logs, post-change verification and clear exit codes.

Exit codes are `0` success, `2` invalid or unsafe input, `3` missing privileges or prerequisites, `4` cancelled, `5` action failure and `6` verification failure.

## Safety

Confirm that the account is genuinely stale and that no services, scheduled tasks, applications or devices depend on it. The tool does not delete objects, remove group membership or bulk-remediate the report automatically.

## Author

Dewald Pretorius — L2 IT Support Engineer
