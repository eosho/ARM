function Invoke-ARMRestMethod {
  <#
    .SYNOPSIS
    Invokes a Rest call to azure and adds the token to header parameter

    .DESCRIPTION
    Invokes a Rest call to azure and adds the token to header parameter

    .PARAMETER Method
    The method of the rest call

    .PARAMETER Uri
    The uri of the rest call

    .PARAMETER Body
    The body of the rest call as a json string

    .EXAMPLE
    Invoke-ARMRestMethod -Body $body -Method 'Put' -Uri $uri -Headers $header

    .NOTES
    The function returns a pscustombject with the keys InvokeResult, OperationId, CorrelationId
  #>
  [CmdLetBinding()]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Method,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Uri,

    [Parameter()]
    [ValidateNotNull()]
    [string] $Body
  )

  $token = Get-ARMToken

  $irmArgs = @{
    Headers                 = @{
      Authorization = 'Bearer {0}' -f $token.AccessToken
    }
    ErrorAction             = 'Continue'
    Method                  = $Method
    UseBasicParsing         = $true
    ResponseHeadersVariable = 'respHeader'
    StatusCodeVariable      = 'statusCode'
    Uri                     = $Uri
  }

  if ($PSBoundParameters.ContainsKey('Body')) {
    [void] $irmArgs.Add('ContentType', 'application/json')
    [void] $irmArgs.Add('Body', $Body)
  }

  try {
    Write-Information -MessageData  "[$($MyInvocation.MyCommand)] - Sending HTTP $($irmArgs.Method.ToUpper()) request to $($irmArgs.Uri)"
    $invokeResult = Invoke-RestMethod @irmArgs
  } catch {
    $errorMessage = $_.ErrorDetails.Message
    Write-Error -ErrorRecord $_ -ErrorAction Continue
  }

  $operationId = $null
  if ($null -ne $respHeader.'x-ms-request-id') {
    Write-Information -MessageData "[$($MyInvocation.MyCommand)] - Response contains 'OperationId' '$($respHeader.'x-ms-request-id'[0])'"
    $operationId = $respHeader.'x-ms-request-id'[0]
  }

  $correlationId = $null
  if ($null -ne $respHeader.'x-ms-correlation-request-id') {
    Write-Information -MessageData "[$($MyInvocation.MyCommand)] - Response contains 'CorrelationId' '$($respHeader.'x-ms-correlation-request-id'[0])'"
    $correlationId = $respHeader.'x-ms-correlation-request-id'[0]
  }

  [PSCustomObject]@{
    InvokeResult   = $invokeResult
    StatusCode     = $statusCode
    ResponseHeader = $respHeader
    OperationId    = $operationId
    CorrelationId  = $correlationId
    StatusMessage  = $errorMessage
  }
}
