 <#
    .SYNOPSIS
        Stops or starts ARM based VMs in a given Resource Group that do not contain '01' in the name

    .DESCRIPTION
        Stops any VM that does not contain '01' in the specified resource group
        Starts any stopped VMs in the specified resource group
        Any VM(s) that have '01' in the name will not be affected

    .PARAMETER SubscriptionName
        The Azure subscription name

    .PARAMETER ResourceGroup
        The Azure resource group name

    .PARAMETER Action
        The action to take (stop or start)

    .NOTES
        Version: 1.0
        Author: Scott Brewerton
        Creation Date:  20180424
#>

Param
(
    [String][Parameter(Mandatory=$true)]$SubscriptionName,
    [String][Parameter(Mandatory=$true)]$ResourceGroup,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateSet("Stop","Start","stop","start")]
    [String]$Action
)

$Action = $Action.ToLower()

Workflow Start-Stop-VMs
{
    Param
    (
        [String]$SubscriptionName,
        [String]$ResourceGroup,
        [String]$Action
    )

    $Conn = Get-AutomationConnection -Name "AzureRunAsConnection"
    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    Get-AzureRmSubscription |  Where-Object SubscriptionName -eq $SubscriptionName | Select-AzureRmSubscription

    Write-Output "Getting VMs...."
    $VMs = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Status | Where-Object -Property Name -NotLike "*01*" | Select-Object -Property Name,PowerState

    $VMs

    Switch -CaseSensitive ($Action)
    {
        start
        {
            Foreach -parallel ($VM in $VMs)
            {
                If ($VM.PowerState -ne "Running")
                {
                    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
                    Write-Output "Starting virtual machine..." $VM.Name
                    Start-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroup
                }
            }
        }
        stop
        {
            Foreach -parallel ($VM in $VMs)
            {
                If($VM.PowerState -ne "VM deallocated")
                {
                    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
                    Write-Output "Stopping virtual machine..." $VM.Name
                    Stop-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroup -Force
                }
            }
        }
    }
}

Start-Stop-VMs -SubscriptionName $SubscriptionName -ResourceGroup $ResourceGroup -Action $Action