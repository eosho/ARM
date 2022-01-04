function New-ARMDeploymentScope {
  <#
    .SYNOPSIS
      Returns an ARMScope for a path or for a scope

    .DESCRIPTION
      Returns an ARMScope for a path or for a scope

    .PARAMETER DeploymentScope
      The deployment scope for which to return a scope object.

    .PARAMETER ResourceGroupName
      The name of the resource group for which to return a scope object.

    .PARAMETER ManagementGroupId
      The Id of the management group for which to return a scope object.

    .PARAMETER SubscriptionId
      The subscription id for which to return a scope object.

    .EXAMPLE
      New-ARMDeploymentScope -DeploymentScope "resourcegroup" -ResourceGroupName "MyResourceGroup" -SubscriptionId "MySubscriptionId"
      Return ARMDeploymentScope

    .INPUTS
      Scope

    .OUTPUTS
      [ARMDeploymentScope]
  #>
  [OutputType([ARMDeploymentScope])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  [Alias("Set-ARMDeploymentScope")]
  param (
    [Parameter(Mandatory = $true, ParameterSetName = "scope")]
    [ValidateSet("resourcegroup", "subscription", "managementgroup")]
    [Alias("Scope")]
    [string] $DeploymentScope,

    [Parameter()]
    [Alias("RGName", "rg")]
    [string] $ResourceGroupName,

    [Parameter()]
    [Alias("MgId", "mg")]
    [string] $ManagementGroupId,

    [Parameter(Mandatory = $false)]
    [Alias("SubId", "sub" )]
    [string] $SubscriptionId = (Get-AzContext).Subscription.Id
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

    # lets construct the scope
    if (($ResourceGroupName -and $SubscriptionId) -and ($DeploymentScope -eq "resourcegroup")) {
      $scopePath = '/subscriptions/{0}/resourceGroups/{1}' -f $SubscriptionId, $ResourceGroupName
    } elseif ($SubscriptionId -and $DeploymentScope -eq "subscription") {
      $scopePath = '/subscriptions/{0}' -f $SubscriptionId
    } elseif ($ManagementGroupId -and $DeploymentScope -eq "managementgroup") {
      $scopePath = '/providers/Microsoft.Management/managementGroups/{0}' -f $ManagementGroupId
    } else {
      throw "Must specify either resourcegroup, subscription or managementgroup deployment scope"
    }
    #endregion
  }

  process {
    switch ($PSCmdlet.ParameterSetName) {
      scope {
        if ($PSCmdlet.ShouldProcess("Scope [$DeploymentScope]", 'Create')) {
          $scopeObject = ([ARMDeploymentScope]::new($scopePath))
        }
      }
    }

    return $scopeObject
  }

  end {
    Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
  }
}
