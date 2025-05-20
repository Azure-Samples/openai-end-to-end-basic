# az login -t MicrosoftCustomerLed.onmicrosoft.com
LOCATION=eastus2
RESOURCE_GROUP=rg-chat-ckm03-${LOCATION}
az group create -l $LOCATION -n $RESOURCE_GROUP
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create -f ./newcopy.bicep -g $RESOURCE_GROUP -n new --parameters userPrincipalId=$PRINCIPAL_ID
