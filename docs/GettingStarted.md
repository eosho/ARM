## Getting Started

To get started working with this repository make sure [PowerShell Core](https://github.com/powershell/powershell) is installed on your system. Within PowerShell make sure you have the [Pester](https://github.com/pester/Pester) and the latest [Az](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.5.0) Modules installed as the testing framework relies on these.

```powershell
Install-Module Pester -Scope CurrentUser
Install-Module -Name Az -AllowClobber -Scope CurrentUser
```

## Clone the repository

These steps assume that the `git` command is on your path.

1. Open a terminal window
2. Navigate to a folder where you want to store the source for the toolkit. For, e.g. `c:\git`, navigate to that folder.
3. Run `git clone https://xxxx@dev.azure.com/xxxx/xxxx/_git/xxxx`. This will clone the GitHub repository in a folder named `xxxx`.
4. Run `cd xxxx` to change directory in the source folder.
5. Run `git checkout -b feature/newFeature` to switch to the branch with the current in-development version is current.

Once locally cloned, run the following PowerShell code to setup the git client side hooks.

```powershell
.\Setup.ps1
```

## Development Strategy

The Development Strategy used for this project is [trunked based development](https://trunkbaseddevelopment.com/). This strategy keeps things as simple as possible by maintaining only a master or main branch. Development work is done in feature branches which, once finished, are merged directly into master or main.
