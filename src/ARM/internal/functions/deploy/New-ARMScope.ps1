function New-ARMScope {
  <#
    .SYNOPSIS
      Returns an ARMScope for a path or for a scope

    .DESCRIPTION
      Returns an ARMScope for a path or for a scope

    .PARAMETER Scope
      The scope for which to return a scope object.

    .PARAMETER ResourceGroupName
      The name of the resource group for which to return a scope object.

    .PARAMETER ManagementGroupName
      The name of the management group for which to return a scope object.

    .PARAMETER SubscriptionId
      The subscription id for which to return a scope object.

    .EXAMPLE
      New-ARMScope -Scope "resourcegroup" -ResourceGroupName "MyResourceGroup" -SubscriptionId "MySubscriptionId"
      Return ARMDeploymentScope

    .INPUTS
      Scope

    .OUTPUTS
      [ARMDeploymentScope]
  #>
  [OutputType([ARMDeploymentScope])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  [Alias("Set-ARMScope")]
  param (
    [Parameter(ParameterSetName = "scope")]
    [ValidateSet("resourcegroup", "subscription", "managementgroup", "tenant")]
    [string] $Scope,

    [Parameter()]
    [Alias('RGName')]
    [string] $ResourceGroupName,

    [Parameter()]
    [Alias('MgName')]
    [string] $ManagementGroupName,

    [Parameter(Mandatory = $false)]
    [Alias('SubId')]
    [string] $SubscriptionId = (Get-AzContext).Subscription.Id
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

    # lets construct the scope
    if ($ResourceGroupName -and $scope -eq "resourcegroup") {
      $scopePath = '/subscriptions/{0}/resourceGroups/{1}' -f $SubscriptionId, $ResourceGroupName
    } elseif ($SubscriptionId -and $scope -eq "subscription") {
      $scopePath = '/subscriptions/{0}' -f $SubscriptionId
    } elseif ($ManagementGroupName -and $scope -in @("managementgroup", "tenant")) {
      $scopePath = '/providers/Microsoft.Management/managementGroups/{0}' -f $ManagementGroupName
    } else {
      throw "Must specify either resourcegroup or subscription scope"
    }
    #endregion
  }

  process {
    switch ($PSCmdlet.ParameterSetName) {
      scope {
        if ($PSCmdlet.ShouldProcess("Scope [$scope]", 'Create')) {
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
