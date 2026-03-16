# Sentinel Watchlist Cleanup – Logic App

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYinonGindi%2FMSSentinel%2Fmain%2FAutomation%2FWatchlistCleanup%2Fazuredeploy.json)

## Overview

This Logic App automatically cleans up stale entries from a Microsoft Sentinel watchlist. It runs on a weekly schedule and removes any watchlist item whose **Date** column is older than a configurable retention period (default: 60 days).

The watchlist is expected to have at least two columns:

| Column | Format | Description |
|---|---|---|
| `IPAddress` | IP address | The indicator value |
| `Date` | `dd/MM/yy` | The date the entry was added |

## How It Works

```
┌─────────────────────┐
│   Weekly Trigger     │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ Initialize Cutoff   │──► utcNow() − retentionDays
└─────────┬───────────┘
          ▼
┌─────────────────────┐   ┌──────────────────────┐
│ Get Watchlist Items  │   │ Get Watchlist Info    │  (parallel)
│ (V2 connector)       │   │ (metadata for PUT)   │
└─────────┬───────────┘   └──────────┬───────────┘
          └──────────┬───────────────┘
                     ▼
          ┌─────────────────────┐
          │ Filter: keep items  │──► Date > cutoffDate
          │ newer than cutoff   │
          └─────────┬───────────┘
                    ▼
          ┌─────────────────────┐
          │ Select key-value    │──► strip metadata
          │ data only           │
          └─────────┬───────────┘
                    ▼
            ┌───────────────┐
            │ Items to keep?│
            └───┬───────┬───┘
           Yes  │       │  No
                ▼       ▼
         ┌──────────┐  ┌──────────────────┐
         │ Build CSV│  │ Delete watchlist  │
         │ table    │  │ (all items stale) │
         └────┬─────┘  └────────┬─────────┘
              ▼                 ▼
         ┌──────────┐  ┌──────────────────┐
         │ Delete   │  │ Wait 5 minutes   │
         │ watchlist│  └────────┬─────────┘
         └────┬─────┘           ▼
              ▼        ┌──────────────────┐
         ┌──────────┐  │ Recreate empty   │
         │ Wait 5   │  │ watchlist (PUT)  │
         │ minutes  │  └──────────────────┘
         └────┬─────┘
              ▼
         ┌──────────┐
         │ Recreate │
         │ watchlist│
         │ with CSV │
         └──────────┘
```

## Prerequisites

1. **Microsoft Sentinel** enabled on a Log Analytics workspace
2. An existing **watchlist** with columns `IPAddress` and `Date` (format: `dd/MM/yy`)
3. Permissions to deploy resources in the target subscription

## Deployment Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `logicAppName` | | `Sentinel-CleanupWatchlist` | Name of the Logic App resource |
| `location` | | Resource group location | Azure region |
| `workspaceId` | ✅ | — | Log Analytics workspace ID (GUID) |
| `workspaceResourceGroup` | ✅ | — | Resource group of the workspace |
| `watchlistAlias` | | `ioc` | Alias of the target watchlist |
| `retentionDays` | | `60` | Items older than this many days are removed |

## What Gets Deployed

| Resource | Type | Purpose |
|---|---|---|
| Logic App | `Microsoft.Logic/workflows` | The cleanup workflow with system-assigned managed identity |
| API Connection | `Microsoft.Web/connections` | Sentinel connector (managed identity auth) |
| Role Assignment | `Microsoft.Authorization/roleAssignments` | Grants **Microsoft Sentinel Contributor** on the workspace |

## Post-Deployment

After deployment, verify the Logic App's managed identity has the **Microsoft Sentinel Contributor** role on the workspace. The template assigns this automatically, but if the workspace is in a different subscription you may need to assign it manually.

### Manual Role Assignment (if needed)

```bash
az role assignment create \
  --assignee "<managed-identity-principal-id>" \
  --role "Microsoft Sentinel Contributor" \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace>"
```

The `managedIdentityPrincipalId` is available in the deployment outputs.

## Notes

- The Logic App uses a **delete-then-recreate** approach because the Sentinel API does not support bulk item deletion. The watchlist is deleted, then re-created with only the non-stale items via a CSV PUT.
- A **5-minute wait** is included between delete and recreate to allow the backend to fully process the deletion.
- The **Date** column must be in `dd/MM/yy` format (e.g., `15/03/26` for March 15, 2026). The workflow parses this into ISO 8601 for comparison.
- If **all items are stale**, the else branch deletes and recreates an empty watchlist to preserve the watchlist structure.
