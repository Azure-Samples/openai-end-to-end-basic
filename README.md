# Azure OpenAI end-to-end basic reference implementation

This reference implementation illustrates a basic approach for authoring and running a chat application in a single region with Prompt flow and Azure OpenAI. This reference implementation supports the [Basic Azure OpenAI end-to-end chat reference architecture](https://learn.microsoft.com/azure/architecture/ai-ml/architecture/basic-openai-e2e-chat).

The implementation will have you build and testing a [Prompt flow](https://microsoft.github.io/promptflow/) in Azure AI Studio, deploy the flow to an Azure Machine Learning online managed endpoint. You'll be exposed to common generative AI chat application characteristics such as:

- Creating prompts
- Querying data stores for grounding data
- Python code
- Calling language models (such as GPT models)

The reference implementation illustrates a basic example of a chat application. For a reference implementation that implements more enterprise requirements, please see the [OpenAI end-to-end baseline reference implementation](https://github.com/Azure-Samples/openai-end-to-end-baseline). That implementation addresses many of the [production readiness changes](https://github.com/search?q=repo%3AAzure-Samples%2Fopenai-end-to-end-basic+%22Production+readiness+change%22&type=code) identified in this code.

## Architecture

The implementation covers the following scenarios:

1. Authoring a flow - Authoring a flow using Prompt flow in Azure AI Studio
1. Deploying a flow - The client UI is hosted in Azure App Service and accesses the Azure OpenAI Service via a Managed online endpoint.

### Deploying a flow to Azure Machine Learning managed online endpoint

![Diagram of the architecture for deploying a flow to Azure Machine Learning managed online endpoint hosted in Azure AI Studio. It shows an App Service hosting a sample application fronting an Azure AI Studio project with associated connections and services. ](docs/media/openai-end-to-end-basic.png)

The architecture diagram illustrates how a front-end web application connects to a managed online endpoint hosting the Prompt flow logic.

## Deployment guide

Follow these instructions to deploy this example to your Azure subscription, try out what you've deployed, and learn how to clean up those resources.

### Prerequisites

- An [Azure subscription](https://azure.microsoft.com/free/) with the following resource providers [registered](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider).

  - `Microsoft.AlertsManagement`
  - `Microsoft.CognitiveServices`
  - `Microsoft.ContainerRegistry`
  - `Microsoft.KeyVault`
  - `Microsoft.Insights`
  - `Microsoft.MachineLearningServices`
  - `Microsoft.ManagedIdentity`
  - `Microsoft.OperationalInsights`
  - `Microsoft.Storage`

- Your deployment user must have the following permissions at the subscription scope:

  - Ability to assign [Azure roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles) on newly created resource groups and resources. (E.g. `User Access Administrator` or `Owner`) 
  - Ability to purge deleted AI services resources. (E.g. `Contributor` or `Cognitive Services Contributor`)

- The [Azure CLI installed](https://learn.microsoft.com/cli/azure/install-azure-cli)

- The [az Bicep tools installed](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)

### 1. :rocket: Deploy the infrastructure

The following steps are required to deploy the infrastructure from the command line.

1. In your shell, clone this repo and navigate to the root directory of this repository.

   ```bash
   git clone https://github.com/Azure-Samples/openai-end-to-end-basic
   cd openai-end-to-end-basic
   ```

1. Log in and set subscription

   ```bash
   az login
   az account set --subscription xxxxx
   ```

1. Set the deployment location.

   Because this solution uses Azure AI Studio, the location MUST be one of: `southcentralus`, `westeurope`, `southeastasia`, `japaneast` to support all resources deployed.

   ```bash
   # TODO: Figure out what the real restrictions are here, if any. What should be the new default location?
   LOCATION=southcentralus
   ```

1. Set the base name value that will be used as part of the Azure resource names for the resources deployed in this solution.

   ```bash
   BASE_NAME=<base resource name, between 6 and 8 lowercase characters, most resource names will include this text>
   ```

1. Create a resource group and deploy the infrastructure.

   ```bash
   RESOURCE_GROUP=rg-chat-basic-${LOCATION}
   az group create -l $LOCATION -n $RESOURCE_GROUP

   PRINCIPAL_ID=$(az ad signed-in-user show --query id --output tsv)

   # This takes about 10 minutes to run.
   az deployment group create -f ./infra-as-code/bicep/main.bicep \
     -g $RESOURCE_GROUP \
     -p baseName=${BASE_NAME} \
     -p yourPrincipalId=$PRINCIPAL_ID
   ```

### 2. Deploy a Prompt flow from Azure AI Studio

To test this architecture, you'll be deploying a pre-built Prompt flow. The Prompt flow is "Chat with Wikipedia" which adds a Wikipedia search as grounding data.

1. Open Azure AI Studio's projects by going to <https://ai.azure.com/allProjects>.

1. Click on the 'Chat with Wikipedia project' project name. This is the project where you'll deploy your flow.

1. Click on **Prompt flow** in the left navigation.

1. On the **Flows** tab, click **+ Create**.

1. Under Explore gallery, find "Chat with Wikipedia" and click **Clone**.

1. Set the Folder name to `chat_wiki` and click **Clone**.

   This copies a starter Prompt flow template into your Azure Files storage account. This action is performed by the managed identity of the project. After the files are copied, then you're directed to a Prompt flow editor. That editor experience uses your own identity for access to Azure Files.

1. Connect the the `extract_query_from_question` Prompt flow step to your Azure OpenAI model deployment.

      - For **Connection**, select 'aoai' from the dropdown menu. This is your deployed Azure OpenAI instance.
      - For **deployment_name**, select 'gpt35' from the dropdown menu. This is the model you've deployed in that Azure OpenAI instance.
      - For **response_format**, select '{"type":"text"}' from the dropdown menu

1. Connect the the `augmented_chat` Prompt flow step to your Azure OpenAI model deployment.

      - For **Connection**, select the same 'aoai' from the dropdown menu.
      - For **deployment_name**, select the same 'gpt35' from the dropdown menu.
      - For **response_format**, also select '{"type":"text"}' from the dropdown menu.

1. Work around a telemetry issue that results in an error at the point of inferencing.

   At the time of this writing, there is a Prompt flow + OpenTelemetry related [bug](https://github.com/microsoft/promptflow/issues/3751) that manifests itself after the Prompt flow is deployed to a managed online endpoint. Proper requests to the `/score` endpoint result in an error response of `unsupported operand type(s) for +: 'NoneType' and 'NoneType'`. To correct that, perform the following steps.

   1. Open the **Files** view.
   1. Select 'requirements.txt'.
   1. The file should be empty, add one line containing just `promptflow-tracing>=1.16.1`.
   1. Click **Save only** and close the file.

1. Click **Save** on the flow.

### 3. Test the Prompt flow from Azure AI Studio

Here you'll test your flow by invoking it directly from the Azure AI Studio. The flow still requires you to bring compute to execute it from. The compute you'll use when in the portal is the default *Serverless* offering, which is only used for portal-based Prompt flow experiences. The interactions against Azure OpenAI are performed by your identity; the bicep template has already granted your user data plane access.

1. Click **Start compute session**.

1. :clock8: Wait for that button to change to *Compute session running*. This may take about five minutes.

   If you get an error related to pip and dependency resolver, this is because of the temporary workaround you followed in the prior steps, this is safe to ignore.

   *Do not advance until the serverless compute is running.*

1. Click the enabled **Chat** button on the UI.

1. Enter a question that would require grounding data through recent Wikipedia content, such as a notable current event.

1. A grounded response to your question should appear on the UI.

### 4. Deploy the Prompt flow to an Azure Machine Learning managed online endpoint

Here you'll take your tested flow and deploy it to a managed online endpoint.

1. Click the **Deploy** button in the UI.

1. Choose **Existing** endpoint and select the one called *ept-chat-BASE_NAME*.

1. Set the following Basic settings, and click **Next**.

   - **Deployment name**: ept-chat-deployment
   - **Virtual machine**: Choose a small virtual machine size from which you have quota. 'Standard_D2as_v4' is plenty for this sample.
   - **Instance count**: 3. This is the recommended minimum count.
   - **Inferencing data collection**: Enabled

1. Set the following Advanced settings, and click **Next**.

   - **Deployment tags**: You can leave blank
   - **Environment**: Use environment of current flow definition
   - **Application Insights diagnostics**: Enabled

1. Ensure the Output & connections settings are still set to the same connection name and deployment name as configured in the Prompt flow, and click **Next**.

1. Click the **Create** button.

1. :clock9: Wait for the deployment to finish creating.

   The deployment can take over ten minutes to create. To check on the process, navigate to the **Deployments** screen using the link in the left navigation. Eventually 'ept-chat-deployment' will be on this list and then eventually the deployment will be listed with a State of 'Succeeded'. Use the **Refresh** button as needed.

   *Do not advance until this deployment is complete.*

### 5. Test the deployed Prompt flow from Azure AI Studio

1. Click on the deployment name, 'ept-chat-deployment'.

1. Click on the **Test** tab.

1. Verify the managed online endpoint is working by asking a similar question that you did from the Prompt flow screen.

### 6. Publish the chat front-end web app

Workloads build chat functionality into an application. Those interfaces usually call APIs which in turn call into Prompt flow. This implementation comes with such an interface. You'll deploy it to Azure App Service using its [run from package](https://learn.microsoft.com/azure/app-service/deploy-run-package) capabilities.

```bash
APPSERVICE_NAME=app-$BASE_NAME

az webapp deploy --resource-group $RESOURCE_GROUP --name $APPSERVICE_NAME --type zip --src-url https://raw.githubusercontent.com/Azure-Samples/openai-end-to-end-basic/main/website/chatui.zip
```

## :checkered_flag: Try it out. Test the deployed application.

After the deployment is complete, you can try the deployed application by navigating to the Web App's URL in a web browser. The URL is https:\//BASE_NAME.azurewebapps.net.

You can also execute the following from your workstation. This command usually does not work from Azure Cloud Shell.

```bash
az webapp browse --resource-group $RESOURCE_GROUP --name $APPSERVICE_NAME
```

Once you're there, ask your solution a question. Like before, you question should ideally involve recent data or events, something that would only be known by the RAG process including content from Wikipedia.

## :broom: Clean up resources

Most Azure resources deployed in the prior steps will incur ongoing charges unless removed.  Additionally, a few of the resources deployed go into a soft delete status which may restrict the ability to redeploy another resource with the same name and may not release quota so it is best to purge any soft deleted resources once you are done exploring.  Use the following commands to delete the deployed resources and resource group and to purge each of the resources with soft delete.  

> **Note:** This will completely delete any data you may have included in this example and it will be unrecoverable.

```bash
az group delete --name $RESOURCE_GROUP -y

# Purge the soft delete resources
az keyvault purge -n kv-${BASE_NAME} -l $LOCATION 
az cognitiveservices account purge -g $RESOURCE_GROUP -l $LOCATION --name oai-${BASE_NAME}
```

## Contributions

Please see our [Contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Azure Patterns & Practices, [Azure Architecture Center](https://azure.com/architecture).
