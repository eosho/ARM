[[_TOC_]]

# Design Principles

These design principles drive the decisions around the Alcatraz architecture.

Contributors should be familiar with these principles before submitting a pull request or recommending a new feature to the current automation.

There are some instances where the current implementation is not consistent with the stated design principles.
However, the intent to always improve consistency.

## Everything-as-Code, Declarative, and Automated

The toolkit is following the common [principles of DevOps](https://docs.microsoft.com/azure/architecture/checklist/dev-ops).

We place an emphasis on [infrastructure-as-code (IaC)](https://en.wikipedia.org/wiki/Infrastructure_as_code) following a [declarative approach](https://en.wikipedia.org/wiki/Declarative_programming). This principle is extended to policy and process (i.e., gated release process).

    Anything that can be managed through code, should be managed in code. This is what is meant by _everything-as-code_.

The declarative model means that the code describes a _desired state_ and that some run-time is responsible for interpreting the code and establishing the desire state. A declarative approach is contrasted against an imperative or procedural approach. An imperative approach provides a set of steps to execute and a desired state can only be infer (at best) from the steps. Azure Resource Manager templates and Azure Policy are declarative.

Automation is a third pillar along with everything-as-code and the declarative approach.
Any change of state should be initiated as a change to source code. The change in source code triggers an automated process, that includes validation and safety checks. This allows for more predictable outcomes and reduces the risk of human error.

    Anything that can be automated, should be automated.

## Common tools for automation and manual process

Any automation should follow the same steps and use the same tools that a developer would use manually.
For example, a CI/CD pipeline in Azure DevOps should invoke the same commands that a human being would use when deploying manually.
By having common tools and procedures, outcomes are more predictable.
