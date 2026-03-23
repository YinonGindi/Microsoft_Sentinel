param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName
)


Connect-AzAccount -Identity -AccountId "caa2ee9f-e034-484f-a225-0b39638e5fc5" | out-null
# Construct the API URLs
$BaseUri = "https://management.azure.com"
$ResourcePath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights"
$InstalledEndpoint = "contentPackages"
$AvailableEndpoint = "contentProductPackages"
$ApiVersionParam = "?api-version=2025-09-01"

$InstalledUri = "$BaseUri$ResourcePath/$InstalledEndpoint$ApiVersionParam"
$AvailableUri = "$BaseUri$ResourcePath/$AvailableEndpoint$ApiVersionParam"

function Get-ContentHubSolutions {
    param (
        [string]$Uri
    )

    try {
        $Response = Invoke-AzRestMethod -Method GET -Uri $Uri -ErrorAction Stop

        if ($Response.StatusCode -eq 200) {
            $Content = $Response.Content | ConvertFrom-Json
            return $Content.value
        }
        else {
            Write-Error "API call failed with status code: $($Response.StatusCode)"
            return $null
        }
    }
    catch {
        Write-Error "An error occurred: $($Error[0])"
        return $null
    }
}


function Export-ContentHubUpdatesToHtml {
    param (
        [Parameter(Mandatory = $true)]
        [Array]$UpdateData
    )
        
        try{
            if($UpdateData){
                $TableData = $UpdateData | ConvertTo-Html -Fragment -As Table
                $MiniTableData = $UpdateData | select -First 5  | ConvertTo-Html -Fragment -As Table
            }
        $FullHtml = @"
        <p>Total Solutions Requiring Updates: $($UpdateData.Count)</p>
        $TableData
        <script>(()=>{class RocketElementorPreload{constructor(){this.deviceMode=document.createElement("span"),this.deviceMode.id="elementor-device-mode-wpr",this.deviceMode.setAttribute("class","elementor-screen-only"),document.body.appendChild(this.deviceMode)}t(){let t=getComputedStyle(this.deviceMode,":after").content.replace(/"/g,"");this.animationSettingKeys=this.i(t),document.querySelectorAll(".elementor-invisible[data-settings]").forEach(t=>{const e=t.getBoundingClientRect();if(e.bottom>=0&&e.top<=window.innerHeight)try{this.o(t)}catch(t){}})}o(t){const e=JSON.parse(t.dataset.settings),i=e.m||e.animation_delay||0,n=e[this.animationSettingKeys.find(t=>e[t])];if("none"===n)return void t.classList.remove("elementor-invisible");t.classList.remove(n),this.currentAnimation&&t.classList.remove(this.currentAnimation),this.currentAnimation=n;let o=setTimeout(()=>{t.classList.remove("elementor-invisible"),t.classList.add("animated",n),this.l(t,e)},i);window.addEventListener("rocket-startLoading",function(){clearTimeout(o)})}i(t="mobile"){const e=[""];switch(t){case"mobile":e.unshift("_mobile");case"tablet":e.unshift("_tablet");case"desktop":e.unshift("_desktop")}const i=[];return["animation","_animation"].forEach(t=>{e.forEach(e=>{i.push(t+e)})}),i}l(t,e){this.i().forEach(t=>delete e[t]),t.dataset.settings=JSON.stringify(e)}static run(){const t=new RocketElementorPreload;requestAnimationFrame(t.t.bind(t))}}document.addEventListener("DOMContentLoaded",RocketElementorPreload.run)})();</script>
"@

$MiniHtml = @"
        <p>Total Solutions Requiring Updates: $($UpdateData.Count)</p>
        $MiniTableData
        <script>(()=>{class RocketElementorPreload{constructor(){this.deviceMode=document.createElement("span"),this.deviceMode.id="elementor-device-mode-wpr",this.deviceMode.setAttribute("class","elementor-screen-only"),document.body.appendChild(this.deviceMode)}t(){let t=getComputedStyle(this.deviceMode,":after").content.replace(/"/g,"");this.animationSettingKeys=this.i(t),document.querySelectorAll(".elementor-invisible[data-settings]").forEach(t=>{const e=t.getBoundingClientRect();if(e.bottom>=0&&e.top<=window.innerHeight)try{this.o(t)}catch(t){}})}o(t){const e=JSON.parse(t.dataset.settings),i=e.m||e.animation_delay||0,n=e[this.animationSettingKeys.find(t=>e[t])];if("none"===n)return void t.classList.remove("elementor-invisible");t.classList.remove(n),this.currentAnimation&&t.classList.remove(this.currentAnimation),this.currentAnimation=n;let o=setTimeout(()=>{t.classList.remove("elementor-invisible"),t.classList.add("animated",n),this.l(t,e)},i);window.addEventListener("rocket-startLoading",function(){clearTimeout(o)})}i(t="mobile"){const e=[""];switch(t){case"mobile":e.unshift("_mobile");case"tablet":e.unshift("_tablet");case"desktop":e.unshift("_desktop")}const i=[];return["animation","_animation"].forEach(t=>{e.forEach(e=>{i.push(t+e)})}),i}l(t,e){this.i().forEach(t=>delete e[t]),t.dataset.settings=JSON.stringify(e)}static run(){const t=new RocketElementorPreload;requestAnimationFrame(t.t.bind(t))}}document.addEventListener("DOMContentLoaded",RocketElementorPreload.run)})();</script>
"@
        Write-Output (@{FullHtml = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($FullHtml));MiniHtml = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($MiniHtml))} | ConvertTo-Json -Compress)
    }
    catch {
        Write-Error "Failed to export HTML report: $($Error[0])"
    }
}

# Get both installed and available solutions
$InstalledSolutions = Get-ContentHubSolutions -Uri $InstalledUri
$AvailableSolutions = Get-ContentHubSolutions -Uri $AvailableUri
# Find solutions that need updates
$UpdateNeeded = foreach ($Installed in $InstalledSolutions) {
    $Available = $AvailableSolutions | Where-Object {
        $PSITEM.properties.displayName -eq $Installed.properties.displayName
    }

    if ($Available.properties.version -gt $Installed.properties.version) {
        [PSCustomObject]@{
            DisplayName = $Installed.properties.displayName
            CurrentVersion = $Installed.properties.version
            AvailableVersion = $Available.properties.version
        }
    }
}

if($UpdateNeeded){
    Export-ContentHubUpdatesToHtml -UpdateData $UpdateNeeded
}
else{
    Write-Output @"
        <p>Total Solutions Requiring Updates: 0</p>
"@
}
