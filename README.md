# WBA - Rapid Deployment Automation

To get started working on this repository, see the [Getting Started](/docs/GettingStarted.md) guide.

### What are we trying to do

- Provide a [**trustable**](https://trustable.io/) environment
- Provide a method to do application lifecycle management for the **trustable** environment
- Provision an example application into that **trustable** environment
- Attempting to follow the philosophy of [GitOPS](https://www.weave.works/blog/gitops-operations-by-pull-request)

### How are we doing this

- Utilizing [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview) to promote developoment ease and more concise syntax compared to ARM (JSON). You can directly call functions from other resources or modules.
- Infrastructure tests to promote a trusted and deployable environment every single time.
- etc...

### Goals

The goal of the rapid deployment is to promote the following:

- Secure deployment
- Full fledged automation
- Speed and Quality
- Deployable and Repeatable
