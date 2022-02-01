# WBA - Rapid Deployment Automation

To get started working on this repository, see the [Getting Started](/docs/GettingStarted.md) guide.

### What are we trying to do

- Provide a [**trustable**](https://trustable.io/) environment
- Provide a method to do application lifecycle management for the **trustable** environment
- Provision an example application into that **trustable** environment
- Attempting to follow the philosophy of [GitOPS](https://www.weave.works/blog/gitops-operations-by-pull-request)

### How are we doing this

- Utilizing [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview) to promote development ease and more concise syntax compared to ARM (JSON). You can directly call functions from other resources or modules.
- Infrastructure tests to promote a trusted and deployable environment every single time.
- etc...

### Goals

The goal of the rapid deployment is to promote the following:

- Secure deployment
- Full fledged automation
- Speed and Quality
- Deployable and Repeatable

## Reference Docs

Review the following additional reference docs in order before navigating through this repository.

- [How to Deploy](./docs/DeploymentPipeline.md)
- [Unit Testing](./docs/UnitTesting.md)

### DevOps Principles

- [Cultural Manifesto](/docs/devops/CulturalManifesto.md)
- [Definition of Done](/docs/devops/DefinitionOfDone.md)
- [Definition of Ready](/docs/devops/DefinitionOfReady.md)
- [Design Principles](/docs/devops/DesignPrinciples.md)
- [Githooks](/docs/devops/GitHooks.md)

## DISCLAIMER

    These scripts and files are not supported under any Microsoft standard support program or service.

    These scripts and files are provided AS IS without warranty of any kind.
    Microsoft further disclaims all implied warranties including, without limitation,
    any implied warranties of merchantability or of fitness for a particular purpose.

    The entire risk arising out of the use or performance of the scripts
    and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the
    scripts be liable for any damages whatsoever (including, without limitation,
    damages for loss of business profits, business interruption, loss of business
    information, or other pecuniary loss) arising out of the use of or inability
    to use the sample scripts or documentation, even if Microsoft has been
    advised of the possibility of such damages.
