function Get-ARMContextPermissionCheck {
  <#
    .SYNOPSIS
      Validates if context has permission specified in validatePermissionList.

    .DESCRIPTION
      Validates if context has permission specified in validatePermissionList.

    .PARAMETER contextObjectId
      The ObjectId of the Context SPN

    .PARAMETER scope
      Scope of the resource

    .PARAMETER validatePermissionList
      The permission list to perform operation.

    .EXAMPLE
      > Get-ARMContextPermissionCheck -contextObjectId $contextObjectId -scope $scope -validatePermissionList $validatePermissionList
      Validates if context contains anyone of permission mentioned in validatePermissionList
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    $ContextObjectId,

    [Parameter(Mandatory = $true)]
    $Scope,

    [Parameter(Mandatory = $true)]
    $ValidatePermissionList
  )

  process {
    $roleAssignmentPermissionCheck = $false
    $roleAssignmentList = Get-AzRoleAssignment -Scope $scope | Where-Object { $_.ObjectId -eq $contextObjectId }

    foreach ($role in $roleAssignmentList) {
      $roleAssignmentScope = $role.Scope.ToLower()
      if ((-not($scope.contains("/resourcegroups"))) -and $roleAssignmentScope.contains("/resourcegroups")) {
        continue
      }

      if ($scope.contains("/resourcegroups") -and (-not ($scope.contains("/providers")))) {
        if ($roleAssignmentScope.contains("/providers") -and (-not ($roleAssignmentScope.contains("/microsoft.management/managementgroups")))) {
          continue
        }
      }

      foreach ($item in $validatePermissionList) {
        $roleDefinitionId = $role.roleDefinitionId.Substring($role.roleDefinitionId.LastIndexOf('/') + 1)
        if (Get-AzRoleDefinition -Id $roleDefinitionId | Where-Object { $_.Actions -contains $item -or $_.Actions -eq "*" }) {
          $roleAssignmentPermissionCheck = $true
          break
        }
      }

      if ($roleAssignmentPermissionCheck -eq $true) {
        break
      }
    }

    return $roleAssignmentPermissionCheck
  }
}
