# MFA Everywhere (Pilot) – Conditional Access with a Safety Net

## What This Project Is  
This is a **step-by-step guide** (plus PowerShell scripts) to roll out **Microsoft Entra Conditional Access** for Multi-Factor Authentication (**MFA**) in a safe, controlled way.  

We’re not flipping MFA on for everyone at once (and risking a meltdown). Instead:  
- We create a **canary group** — a small test group of users.  
- We set up a **trusted location** (like your office or home IP) so your tests don’t drive you crazy with constant prompts.  
- We add **break-glass accounts** that bypass the policies, so you’ll never lock yourself out.  
- We run the policies in **Report-only mode** first (so you can see what would happen without affecting users).  
- We gather **before/after metrics** straight from Microsoft Graph sign-in logs to prove the change made an impact.  

At the end, you’ll have:
1. A working CA pilot with three policies:
   - **Block legacy authentication**
   - **Require MFA for all apps outside your trusted IP**
   - **Require MFA for Azure management**
2. CSV reports of sign-ins **before** and **after** enabling the policies
3. A **summary report** you can literally paste into your resume

---

## The Big Picture Flow

1. **Connect to Graph** – Grant the right permissions  
2. **Set up the pilot** – Group, trusted IP, CA policies (Report-only)  
3. **Collect “Before” metrics** – Sign-ins for the last 24h  
4. **Enable the CA policies** – Move from Report-only to Enforced  
5. **Collect “After” metrics** – Another 24h window  
6. **Summarize the difference** – Get a clean bullet for your resume  

---

## Requirements Before You Start

- PowerShell 7+ (`pwsh`)
- Microsoft Entra role: **Global Administrator** or **Conditional Access Administrator**
- Install required Graph modules:
  ```pwsh
  Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports -Scope CurrentUser -Force
  ```

---

## Step-by-Step

### 1. Connect to Microsoft Graph
```pwsh
.\scripts\Connect-Graph.ps1
```
This logs you into Graph with the permissions needed for this project.

---

### 2. Set up the pilot
```pwsh
.\scripts\Setup-CAPilot.ps1 -TenantId "<YOUR-TENANT-ID>" `
  -BreakGlassUpns @("breakglass1@contoso.com","breakglass2@contoso.com") `
  -CanaryMemberUpns @("you@contoso.com")
```
What it does:
- Creates (or finds) the **canary group** and adds test users
- Creates (or finds) the **trusted named location** with your public IP
- Creates the **three CA policies** in **Report-only mode**

---

### 3. Collect BEFORE metrics
```pwsh
.\scripts\Collect-CAMetrics.ps1 -HoursBack 24 -CanaryGroupName "IAM-CA-Canary" -CsvOut "$PWD\before.csv" -ShowProgress
```
This pulls the last 24 hours of sign-ins from Graph for your canary group and saves them to `before.csv`.

---

### 4. Enable the CA policies
```pwsh
.\scripts\Toggle-CAPolicies.ps1 -PolicyNames @(
  "CA01 - Block legacy auth (Canary)",
  "CA02 - Require MFA all apps outside Trusted (Canary)",
  "CA03 - Require MFA for Azure management (Canary)"
) -State enabled -AutoDisableSecurityDefaults
```
This turns the policies from Report-only to **Enabled**.  
If **Security Defaults** is still on in your tenant, this script can automatically turn it off so the policies will work.

---

### 5. Collect AFTER metrics
```pwsh
.\scripts\Collect-CAMetrics.ps1 -HoursBack 24 -CanaryGroupName "IAM-CA-Canary" -CsvOut "$PWD\after.csv" -ShowProgress
```

---

### 6. Summarize the results
```pwsh
.\scripts\Summarize-CAMetrics.ps1 -Before "$PWD\before.csv" -After "$PWD\after.csv" -Out "$PWD\summary.txt" -VerboseChecks
```
You’ll get:
- A text summary of how many legacy auth sign-ins were blocked
- MFA enforcement stats
- A ready-to-use resume bullet

---

## Real Issues We Hit (and How We Solved Them)

### **1. Security Defaults Blocked CA Policies**
**The problem:**  
When trying to enable Conditional Access policies, we got:  
```
Security Defaults is enabled in the tenant. You must disable Security defaults before enabling a Conditional Access policy.
```

**Why it happened:**  
Security Defaults is a “blanket security setting” in Entra that blocks custom CA policies from taking over.

**How we fixed it:**  
- Manually: Entra portal → Identity → Properties → Manage security defaults → **No** → Save.  
- Automatically: Used `-AutoDisableSecurityDefaults` in `Toggle-CAPolicies.ps1`.

---

### **2. “File not found” when summarizing**
**The problem:**  
```
Cannot find path '...\after.csv' because it does not exist.
```
**Why it happened:**  
We tried to summarize before collecting the AFTER metrics, or ran the metrics command in the wrong folder.

**How we fixed it:**  
- Always run the `Collect-CAMetrics.ps1` for AFTER metrics before summarizing.
- Use full paths: `"$PWD\after.csv"` to avoid path mix-ups.

---

### **3. Empty CSVs**
**The problem:**  
`before.csv` or `after.csv` had no rows.  

**Why it happened:**  
No one in the canary group had actually signed in during the time window.

**How we fixed it:**  
- Waited for canary users to sign in  
- Used `-HoursBack 48` to widen the window  
- Used `-WidenIfEmpty` to automatically double the window if no sign-ins were found

---

### **4. Missing Graph Module Cmdlets**
**The problem:**  
Commands like `Get-MgAuditLogSignIn` weren’t found.

**Why it happened:**  
The `Microsoft.Graph.Reports` module wasn’t installed.

**How we fixed it:**  
```
Install-Module Microsoft.Graph.Reports -Scope CurrentUser -Force
```

---

## Screenshot Guide

Save all screenshots to `docs/screenshots/` for proof:
| Step | File | Shows |
|---|---|---|
| Connect | `01-connect.png` | Graph connected account + scopes |
| BEFORE | `02-before-summary.png` | Metrics summary for before.csv |
| BEFORE | `03-before-csv.png` | The before.csv in Excel/Notepad |
| Enable | `04-toggle.png` | Policies set to Enabled |
| AFTER | `05-after-summary.png` | Metrics summary for after.csv |
| AFTER | `06-after-csv.png` | The after.csv in Excel/Notepad |
| Summary | `07-summary.png` | Contents of summary.txt |

---

## Uploading to GitHub

1. Create an empty repo on GitHub
2. In your project folder:
   ```pwsh
   git init
   git branch -M main
   git add .
   git commit -m "Initial commit: MFA CA pilot"
   git remote add origin https://github.com/<you>/iam-mfa-pilot.git
   git push -u origin main
   ```
3. Done — your scripts, README, and screenshots are now public.

---
