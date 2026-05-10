Connect-AzAccount -Identity


$rgName = "<ResourceGroupName>";
$wsName = "<LogAnalyticsWorkspaceName"
$retention = 90;
$totalRetention = 365

Write-Output "Fetching tables for workspace: $wsName"

$tables = (Get-AzOperationalInsightsTable -ResourceGroupName $rgName -WorkspaceName $wsName)| where {$_.RetentionInDays -ne $retention -and $_.TotalRetention -ne $totalRetention}
Write-Output "Found $($tables.Count) tables."
foreach ($table in $tables) {
    Write-Output "Processing table: $($table.Name)"
    try {
        Update-AzOperationalInsightsTable -ResourceGroupName $rgName `
                                          -WorkspaceName $wsName `
                                          -TableName $table.Name `
                                          -RetentionInDays $retention `
                                          -TotalRetentionInDays $totalRetention | out-null
        Write-Output "Successfully updated $($table.Name) to $retention days ($totalRetention total)."
    }
    catch {
        Write-Error "Failed to update $($table.Name): $($_.Exception.Message)"
    }
}
