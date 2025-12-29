<#
################################################################################
# Copyright (c) 2025 Omar Miranda
# All rights reserved.
#
# This script is provided "as is" without warranty of any kind, express or
# implied. Use at your own risk.
#
# Author: Omar Miranda
# Created: 2025
################################################################################
<#
.SYNOPSIS
    Manages Active Directory group memberships in bulk.

.DESCRIPTION
    Add or remove users from AD groups:
    - Bulk group membership from CSV
    - Add/remove single user to/from multiple groups
    - Group membership reporting

.PARAMETER CSVPath
    Path to CSV file with columns: Username, GroupName, Action (Add/Remove)

.PARAMETER Username
    Single username to modify

.PARAMETER GroupName
    Group name(s) to add/remove user

.PARAMETER Action
    Add or Remove

.EXAMPLE
    .\Set-ADGroupMembership.ps1 -CSVPath "memberships.csv"
    .\Set-ADGroupMembership.ps1 -Username "jdoe" -GroupName "IT-Team" -Action Add
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, ParameterSetName="CSV")]
    [string]$CSVPath,

    [Parameter(Mandatory=$true, ParameterSetName="Single")]
    [string]$Username,

    [Parameter(Mandatory=$true, ParameterSetName="Single")]
    [string[]]$GroupName,

    [Parameter(Mandatory=$true, ParameterSetName="Single")]
    [ValidateSet("Add", "Remove")]
    [string]$Action
)

Import-Module ActiveDirectory

$results = @()

if ($CSVPath) {
    # Bulk operation from CSV
    $memberships = Import-Csv -Path $CSVPath
    $total = $memberships.Count
    $current = 0

    foreach ($item in $memberships) {
        $current++
        Write-Progress -Activity "Processing group memberships" `
                       -Status "Processing $($item.Username) -> $($item.GroupName)" `
                       -PercentComplete (($current / $total) * 100)

        if ($PSCmdlet.ShouldProcess("$($item.Username)", "$($item.Action) to/from $($item.GroupName)")) {
            try {
                $user = Get-ADUser -Identity $item.Username -ErrorAction Stop
                $group = Get-ADGroup -Identity $item.GroupName -ErrorAction Stop

                if ($item.Action -eq "Add") {
                    Add-ADGroupMember -Identity $group -Members $user
                    Write-Host "[ADDED] $($item.Username) to $($item.GroupName)" -ForegroundColor Green
                    $status = "Success - Added"
                } else {
                    Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
                    Write-Host "[REMOVED] $($item.Username) from $($item.GroupName)" -ForegroundColor Green
                    $status = "Success - Removed"
                }

                $results += [PSCustomObject]@{
                    Username = $item.Username
                    GroupName = $item.GroupName
                    Action = $item.Action
                    Status = $status
                }
            } catch {
                Write-Host "[ERROR] Failed: $($item.Username) - $_" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    Username = $item.Username
                    GroupName = $item.GroupName
                    Action = $item.Action
                    Status = "Failed: $_"
                }
            }
        }
    }
    Write-Progress -Activity "Processing group memberships" -Completed

} else {
    # Single user, multiple groups
    try {
        $user = Get-ADUser -Identity $Username -ErrorAction Stop

        foreach ($group in $GroupName) {
            if ($PSCmdlet.ShouldProcess($Username, "$Action to/from $group")) {
                try {
                    $adGroup = Get-ADGroup -Identity $group -ErrorAction Stop

                    if ($Action -eq "Add") {
                        Add-ADGroupMember -Identity $adGroup -Members $user
                        Write-Host "[ADDED] $Username to $group" -ForegroundColor Green
                        $status = "Success"
                    } else {
                        Remove-ADGroupMember -Identity $adGroup -Members $user -Confirm:$false
                        Write-Host "[REMOVED] $Username from $group" -ForegroundColor Green
                        $status = "Success"
                    }

                    $results += [PSCustomObject]@{
                        Username = $Username
                        GroupName = $group
                        Action = $Action
                        Status = $status
                    }
                } catch {
                    Write-Host "[ERROR] Group $group - $_" -ForegroundColor Red
                    $results += [PSCustomObject]@{
                        Username = $Username
                        GroupName = $group
                        Action = $Action
                        Status = "Failed: $_"
                    }
                }
            }
        }
    } catch {
        Write-Error "User $Username not found: $_"
        exit 1
    }
}

# Export results
if ($results.Count -gt 0) {
    $logPath = "GroupMembership_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $logPath -NoTypeInformation
    Write-Host "`nResults exported to: $logPath" -ForegroundColor Green
    $results | Format-Table -AutoSize
}
