 <#
    .SYNOPSIS
        Stops or starts all.ARM based VMs in a given Resource Group that do not contain '01' in the name

    .DESCRIPTION
        Stops any VM that does not contain '01' in the 'WR-TeamCity-Agents-RG' resource group at 00:00 weekdays
        Starts any stopped VMs in the 'WR-TeamCity-Agents-RG' resource group at 08:00 on weekdays
        This will leave x3 VMs running, x1 for CorInt (wr-cor-tca01-vm), x1 for PayCom (wr-pcom-tca01-vm) and x1 for Web (wr-web-tca01-vm)
        The remaining x11 VMs will be dealloc'd for x8 hours a day
        This will result in a monthly saving of approx. £24 per week for each VM (so £264 per week for all x11)

    .PARAMETER Credential
        Credential used to authenticate via Add-AzureRmAccount - needed for authentication

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
    [String][Parameter(Mandatory=$true)]$SubscriptionName = "SomeSubscriptionm",
    [String][Parameter(Mandatory=$true)]$ResourceGroup = "SomeResourceGroup",
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

    #$VMs

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