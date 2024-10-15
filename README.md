# Azure OpenAI end-to-end basic reference implementation

This reference implementation illustrates a basic approach for authoring and running a chat application in a single region with Azure Machine Learning and Azure OpenAI. This reference implementation supports the [Basic Azure OpenAI end-to-end chat reference architecture](https://learn.microsoft.com/azure/architecture/ai-ml/architecture/basic-openai-e2e-chat).

The implementation takes advantage of [Prompt flow](https://microsoft.github.io/promptflow/) in [Azure Machine Learning](https://azure.microsoft.com/products/machine-learning) to build and deploy flows that can link the following actions required by a generative AI chat application:

- Creating prompts
- Querying data stores for grounding data
- Python code
- Calling language models (such as GPT models)

The reference implementation illustrates a basic example of a chat application. For a reference implementation that implements enterprise requirements, please see the [OpenAI end-to-end baseline reference implementation](https://github.com/Azure-Samples/openai-end-to-end-baseline).

## Architecture

The implementation covers the following scenarios:

1. Authoring a flow - Authoring a flow using Prompt flow in an Azure Machine Learning workspace.
1. Deploying a flow - The client UI is hosted in Azure App Service and accesses the Azure OpenAI Service via a Machine Learning managed online endpoint.

### Deploying a flow to Azure Machine Learning managed online endpoint

![Diagram of the deploying a flow to Azure Machine Learning managed online endpoint.](docs/media/openai-end-to-end-basic.png)

The Azure Machine Learning deployment architecture diagram illustrates how a front-end web application connects to a managed online endpoint.

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

- Your user has permissions to assign [Azure roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles), such as a User Access Administrator or Owner.

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

1. Create a resource group and deploy the infrastructure.

   ```bash
   # Because this solution uses Azure AI Studio, the location MUST be one of: southcentralus, westeurope, southeastasia, japaneast to support all resources deployed
   LOCATION=southcentralus
   BASE_NAME=<base resource name, between 6 and 8 lowercase characters, most resource names will include this text>

   RESOURCE_GROUP=rg-chat-basic-${LOCATION}
   az group create -l $LOCATION -n $RESOURCE_GROUP

   PRINCIPAL_ID=$(az ad signed-in-user show --query id --output tsv)

   # This takes about 10 minutes to run.
   az deployment group create -f ./infra-as-code/bicep/main.bicep \
     -g $RESOURCE_GROUP \
     -p baseName=${BASE_NAME}
     -p yourPrincipalId=$PRINCIPAL_ID
   ```

### 2. Deploy a Prompt flow

To test this architecture, you'll be deploying a pre-built Prompt flow. The prompt flow is "Chat with Wikipedia."

1. Open Azure AI Studio's projects by going to <https://ai.azure.com/allProjects>.

1. Click on the `aiproj-chat-${BASE_NAME}` project. This is the project where you'll deploy your prompt flow.

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

1. Click **Save**.

### 3. Test the Prompt flow out in Azure AI Studio

1. Click **Start compute session**.

1. Wait for that button to change to 'Compute session running.' This may take around five minutes.

1. Click the **Chat** button on the UI.

1. Enter a question that would be something best grounded through recent Wikipedia content.

1. A response to your question should appear on the UI.

### 4. Deploy to Azure Machine Learning managed online endpoint

1. Create a deployment in the UI

   1. Click on 'Deploy' in the UI
   1. Choose 'Existing' Endpoint and select the one called _ept-\<basename>_
   1. Choose a small Virtual Machine size for testing and set the number of instances
   1. Click 'Review + Create'
   1. Click 'Create'

### 5. Publish the chat front-end web app

The baseline architecture uses [run from zip file in App Service](https://learn.microsoft.com/azure/app-service/deploy-run-package). This approach has many benefits, including eliminating file lock conflicts when deploying.

```bash
APPSERVICE_NAME=app-$BASE_NAME

az webapp deploy --resource-group $RESOURCE_GROUP --name $APPSERVICE_NAME --type zip --src-url https://raw.githubusercontent.com/Azure-Samples/openai-end-to-end-basic/main/website/chatui.zip
```

## :checkered_flag: Try it out. Test the deployed application.

After the deployment is complete, you can try the deployed application by navigating to the AppService URL in a web browser.  Once you're there, ask your solution a question, ideally one that involves recent data or events, something that would only be known by the RAG process including content from Wikipedia.

## :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will incur ongoing charges unless removed. Also a few of the resources deployed go into a soft delete status. It's best to purge those once you're done exploring, Key Vault is given as an example here. Azure OpenAI and Azure Machine Learning Workspaces are others that should be purged.

```bash
az group delete --name $RESOURCE_GROUP -y

# Purge the soft delete resources
az keyvault purge -n kv-${BASE_NAME}
az openai purge -n oai-${BASE_NAME}  <-- TODO
az aml purge -n amlw <-- TODO
az ai services purge -n aih-${BASE_NAME} <--- TODO
Role assignment removals
```

## Contributions

Please see our [Contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Azure Patterns & Practices, [Azure Architecture Center](https://azure.com/architecture).
