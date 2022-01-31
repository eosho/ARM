# Rapid Deployment Testing

Individual bicep modules are tested vigorously with the help of [Pester](https://pester.dev/). This is done in order to have a consistent, clean and syntactically correct test and to ensure successful deployments.

The `QA.tests.ps1` script located in `src\ARM\tests\qa` folder is used to perform the Quality assurance stage.

## Requirements

- PowerShell Core
- Pester 5.3.1
- VSCode

## Usage

### Pipeline Tasks (PowerShell Core)

```powershell
Install-Module Pester -RequiredVersion 5.1.1 -Force -ErrorAction Stop

Invoke-Pester -Configuration @{
  Run        = @{
    Path = "$(System.DefaultWorkingDirectory)/src/ARM/tests/qa/*.tests.ps1"
  }
  TestResult = @{
    TestSuiteName = 'Solution Tests'
    OutputPath    = '$(System.DefaultWorkingDirectory)/src/ARM/tests/qa-testResults.xml'
    OutputFormat  = 'NUnitXml'
    Enabled       = $true
  }
  Output     = @{
    Verbosity = 'Detailed'
  }
}
```

### Locally (PowerShell Core)

```powershell
Install-Module Pester -RequiredVersion 5.3.1 -Force -ErrorAction Stop
Invoke-Pester -CI -Output Detailed -Verbose
```

## Unit Tests

For the QA (Unit) tests, we are checking for the following:

- General module folder tests
  - Module should contain a `deploy.json` or `deploy.bicep` file

- Deployment template tests
  - Template file should not be empty
  - Template file should contain required elements: schema, contentVersion, parameters, resources, outputs
  - Schema URI should use https and latest apiVersion
  - Template schema should use `HTTPS` reference
  - Use of camelCasing in the template parameter section
  - Parameter names should be camel-cased (no dashes or underscores and must start with lower-case letter)
  - Variable names should be camel-cased (no dashes or underscores and must start with lower-case letter)
  - Every parameter must  have a `{"metadata": {"description": ""}}` element and value
  - Every resource definition must have a literal `apiVersion`
  - The Location should be defined as a parameter, with the default value of 'resourceGroup().Location' or global for ResourceGroup deployment scope

- Test Deployment
  - Modules are imported successfully
  - Template: `main.bicep` is actually deployable.

### Additional resources

- [Pester wiki](https://github.com/Pester/Pester/wiki)
- [Pester setup and commands](https://pester.dev/docs/commands/setup)
