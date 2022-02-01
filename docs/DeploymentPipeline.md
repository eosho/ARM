# Rapid Deployment Pipeline

[Azure DevOps pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/what-is-azure-pipelines?view=azure-devops) are the CI/CD solution provided by Azure DevOps. The following components in Azure DevOps are also used:

- **[Service connection:](#azure-devops-component-service-connection)** The [service connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml) is a wrapper for the deployment principal that performs all actions in the target subscription
- **[Variable file:](#azure-devops-component-variable-file)** The [variable file](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=example%2Cparameter-schema#variable-templates) is a version controlled variable file that hosts pipeline configuration data such as the agent pool to use.
- **[Pipeline templates:](#azure-devops-component-pipeline-templates)** [Pipeline templates](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops) allow us to re-use pipeline logic across multiple referencing pipelines
- **[Pipeline parameters:](#azure-devops-component-pipeline-parameters)** The pipeline parameters are injected to the deployment at runtime to supply values to scripts and tasks.

## Azure DevOps Component

### **Azure DevOps Component:** Service Connection

The service connection must be set up in the project's settings under _Pipelines: Service connections_ (a step by step guide can be found [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml)).

It's name must match the one configured as `serviceConnection` in the [variable file](#azure-devops-component-variable-file).

### **Azure DevOps Component:** Variable file

The variable file is a source controlled configuration file to control the behavior of the pipeline. The file is stored in path `.config/<environment>.config.yaml`.

This file is consists of the following variables used in the pipelines:

```yaml
  # Environment specific variables
  variables:
  - name: serviceConnection
    value: devSub

  - name: environmentName
    value: dev

  - name: subscriptionId
    value: xxxx-xxxx-xxxx

  - name: subscriptionName
    value: devSub

  - name: location
    value: eastus2

  - name: resourceGroupName
    value: dev-rg
```

More information about the contained variables can be found in the linked file itself.

### **Azure DevOps Component:** Pipeline templates

To keep the amount of pipeline code at a minimum we make heavy use of pipeline templates. Following you can find an overview of the ones we use and what they are used for:

| Template Name | Description |
| - | - |
| **jobs.build.yaml** | This template perform all prerequisites module installation on the hosted agent. |
| **jobs.deploy.yaml** | This template performs a validation or actual deployment to Azure using a provided parameter file. |
| **jobs.initialize.yaml** | This template is capable of configuration your subscription. It is currently limited to enabling resource providers/features, however scope can be extended. |
| **jobs.invokeccp.yaml** | This template is capable of Invoking the CCP pipeline to deploy a resource. |
| **jobs.teardown.yaml** | This template is capable of tearing down/deleting an entire resource group |

Each file can be found in path `.azdo/templates`.

### **Azure DevOps Component:** Pipeline parameters

The following is a list of parameters needed at runtime to run/provision the environment.

| Parameter | Default Value | Possible Values | Type | Description |
|---|---|---|---|---|
| `Environment`| `dev` | `dev`, `uat`, `prod` | string | Deployment environment name |
| `Initialize Subscription` | `false` | `true`, `false` | string | Whether to configure the subscription before the deployment begins. You can customize this stage of the deployment. |
| `Trigger CCP Pipeline` | `false` | `true`, `false` | boolean | Option to trigger CCP pipeline to deploy resources |
| `Values needed for CCP` | `{}` | `- resource: '' serviceConnection: '' templateParameterFilePath: '' displayName: ''` | object | Values to be passed for CCP deployment. Depended on `Trigger CCP Pipeline` set to `true` |
| `Validate Deployment` | `none` | `none`, `validate`, `validateWhatIf` | string | Option to deploy, validate or perform a whatIf validation |
| `Destroy Environment` | `false` | `true`, `false` | boolean | Whether or not to delete the entire resource group |

### How to deploy

A YAML [deployment pipeline](https://dev.azure.com/xxx/xxxx/_build?definitionId=xxxx) has been developed as the CI/CD solution to deploy these policies. Simply select **Run pipeline** and enter the parameter values as required.
