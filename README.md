MFA Everywhere (Pilot) — with a Break-Glass Guardrail

A realistic, PowerShell-driven pilot for Microsoft Entra Conditional Access that is safe to try, measurable, and easy to roll back.
The goal: move from “we turned on MFA” to “we rolled out MFA with a controlled blast radius, telemetry, and a clean exit hatch.”
What this repo does

    Canary-first rollout: start with a small pilot group, run policies in Report-only, then enable.

    Trusted test egress (pilot-only): use a narrow corp/VPN egress IP range to cut prompt fatigue during testing; remove it at cleanup.

    Break-glass accounts: excluded from CA so you cannot lock yourself out.

    Telemetry: gather before/after sign-in metrics from Microsoft Graph to show impact.

    Rollback: a safe script to unwind the pilot and optionally re-enable Security Defaults.

Requirements

    Microsoft Entra ID P1 (for Conditional Access).
    P2 only if you plan to use risk-based or Identity Protection features (not required for this pilot).

    PowerShell 7+

    Microsoft Graph PowerShell SDK

    Install the modules (run as a non-elevated user is fine):
    Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports -Scope CurrentUser -Force
Preflight checklist (strongly recommended)

You have two emergency access (break-glass) accounts, excluded from CA, with permanent Global Administrator, strong unique credentials or hardware keys, no mailbox, and alerting on any sign-in.

You know your current Security Defaults status (enabled/disabled).

You have or will create a canary pilot group (small, non-privileged users).

You have a temporary corp/VPN egress IP range for a trusted named location (pilot-only).

You’ve decided how to handle SMTP AUTH (disable tenant-wide or allow per-mailbox only if required).

    You have access to view Sign-in logs in Entra / Graph.

Permissions & consent (least privilege)

This pilot uses delegated Graph scopes. When connecting, consent to:

    Policy.ReadWrite.ConditionalAccess — manage CA policies & named locations

    Policy.Read.All — read CA policies & named locations

    AuditLog.Read.All — read sign-in logs for before/after metrics

Example: Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Policy.Read.All","AuditLog.Read.All"
If your tenant requires admin consent, an Entra admin must approve these scopes once.
Quick start

    Tip: run Get-Help on each script for parameters and examples
    e.g., Get-Help .\scripts\Setup-CAPilot.ps1 -Detailed

    1. Clone 
    git clone https://github.com/<your-org-or-user>/iam-mfa-pilot.git
    cd iam-mfa-pilot
    2. Connect to Microsoft Graph
    Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Policy.Read.All","AuditLog.Read.All"
    3. Set up the pilot artifacts
    Creates the canary group and a temporary trusted named location (corp/VPN egress).
     .\scripts\Setup-CAPilot.ps1
    4. Deploy policies in Report-only
    .\scripts\Toggle-CAPolicies.ps1 -Mode ReportOnly
    5. Validate with What-If
Entra admin center → Security → Conditional Access → What-If → test typical user and scenario.
    6. Enable for the canary group (controlled blast radius)
    .\scripts\Toggle-CAPolicies.ps1 -Mode On
    7. Measure impact (before/after)
Use the provided metrics commands or workbook notes below.
    8. Widen scope (optional)
If clean in canary, expand to additional groups in stages.
    9. Cleanup / Rollback (if needed)
    .\scripts\Rollback.ps1 -ReEnableSecurityDefaults
Measurement & reporting

    The pilot reads Sign-in logs via Graph (/auditLogs/signIns) to compute:

        % of canary users with successful interactive sign-ins

        MFA prompt rate and failure rate

        Presence of appliedConditionalAccessPolicies to verify effect

    Consider the Conditional Access insights & reporting workbook as a visual cross-check.

    If you export CSVs (e.g., before.csv / after.csv) for analysis, make sure they are sanitized (no real UPNs/IPs) before committing.

Trusted named location (pilot-only)

    Use a narrow corporate/VPN egress range to reduce prompt fatigue during testing.

    Avoid home ISP ranges (dynamic/IPv6 can lead to gaps).

    Remove this trusted location during cleanup.

Security Defaults vs Conditional Access

Security Defaults and Conditional Access aren’t designed to run together.
The setup/toggle steps can temporarily disable Security Defaults so CA policies can be created and tested. If anything looks off, use:
.\scripts\Rollback.ps1 -ReEnableSecurityDefaults
…to disable pilot policies, remove temporary artifacts, and re-enable Security Defaults.
Break-glass account guidance (operationally important)

    Maintain at least two emergency access accounts.

    Exclude from all Conditional Access policies.

    Assign permanent Global Administrator; don’t use for daily work; no mailbox.

    Use long, non-expiring passwords or hardware keys.

    Monitor and alert on any sign-in activity from these accounts.

Legacy/Basic auth note (SMTP AUTH)

Blocking legacy protocols via Conditional Access helps, but SMTP AUTH is controlled in Exchange Online:

    Prefer tenant-wide disable:
    Set-TransportConfig -SmtpClientAuthenticationDisabled $true
Allow per-mailbox only if truly required:
Set-CASMailbox -Identity <user> -SmtpClientAuthenticationDisabled $false
Scripts included (at a glance)

    scripts/Setup-CAPilot.ps1
    Creates pilot artifacts (canary group, temporary trusted named location) and prepares CA policy scaffolding.

    scripts/Toggle-CAPolicies.ps1
    Switches pilot policies between ReportOnly and On for the canary scope.

    scripts/Rollback.ps1
    Disables pilot CA policies, removes the temporary named location, and optionally re-enables Security Defaults.
    Examples:
    # Dry run
.\scripts\Rollback.ps1 -WhatIf

# Full rollback and re-enable Security Defaults
.\scripts\Rollback.ps1 -ReEnableSecurityDefaults

# With explicit names (if you customized policy/location names)
.\scripts\Rollback.ps1 -PolicyNames "MFA Pilot - Require MFA (Canary)","MFA Pilot - Block legacy auth (Canary)","MFA Pilot - Session controls (Canary)" -NamedLocation "MFA Pilot - Trusted Test Egress"
Note: If you changed display names for policies or the named location, update the parameters when running Rollback.ps1.
Pilot flow (visual checklist)

    Create canary group + temporary trusted test egress

    Deploy policies in Report-only

    Validate with What-If

    Flip to On for canary

    Capture before/after metrics

    Expand scope (if clean)

    Cleanup: disable pilot policies, remove named location, (optionally) re-enable Security Defaults

FAQ

Why not enable MFA tenant-wide right away?
Because you want a controlled blast radius, data to prove impact, and a rollback plan.

Will this lock out admins?
No—the break-glass accounts are excluded, and policies start in Report-only.

What if Security Defaults were already enabled?
The pilot can disable them temporarily; Rollback.ps1 restores your baseline quickly.

Do I need P2?
No—only if you’re adding risk-based or Identity Protection policies. P1 is sufficient for this pilot.
Contributing

Issues and PRs are welcome. Please sanitize any logs or screenshots (no real UPNs, tenant IDs, or IPs).
License

MIT (or your chosen license). Add a LICENSE file if not present.
One last safety note

Treat the trusted named location as pilot-only and remove it at the end. The strongest MFA rollouts balance security, usability, and telemetry—and leave a clean exit hatch.




    
     

