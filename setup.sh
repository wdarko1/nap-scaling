#!/bin/bash

readinput () {
    # $1: name
    # $2: default value
    local VALUE
    read -p "${1} (default: ${2}): " VALUE
    VALUE="${VALUE:=${2}}"
    echo "${VALUE}"
}


echo ""
echo "========================================================"
echo "|                 NAP DEMO SETUP                |"
echo "========================================================"
echo ""

# Variables
PREFIX=demo
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
LOCATION=`readinput "Location" "uksouth"`
PREFIX=`readinput "Prefix" "${PREFIX}"`
RANDOMSTRING=`readinput "Random string" "$(mktemp --dry-run XXX | tr '[:upper:]' '[:lower:]')"`
IDENTIFIER="${PREFIX}${RANDOMSTRING}"
CLUSTER_RG=`readinput "Resource group" "${IDENTIFIER}-rg"`
CLUSTER_NAME="${IDENTIFIER}"
DEPLOYMENT_NAME="${IDENTIFIER}-deployment"
AVAILABLE_K8S_VERSIONS=$(az aks get-versions --location ${LOCATION} --query "sort(values[?isPreview == null][].patchVersions.keys(@)[-1])" -o tsv | tr '\n' ',' | sed 's/,$//')
LATEST_K8S_VERSION=$(az aks get-versions --location ${LOCATION} --query "sort(values[?isPreview == null][].patchVersions.keys(@)[-1])[-1]" -o tsv)
K8S_VERSION=`readinput "Kubernetes version (${AVAILABLE_K8S_VERSIONS})" "${LATEST_K8S_VERSION}"`


echo ""
echo "========================================================"
echo "|               ABOUT TO RUN THE SCRIPT                |"
echo "========================================================"
echo ""
echo "Will execute against subscription: ${AZURE_SUBSCRIPTION_ID}"
echo "To change, terminate the script, run az account set --subscription <subscrption id> and run the script again."
echo "Continue? Type y or Y."
read REPLY
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit
fi

echo ""
echo "========================================================"
echo "|               CONFIGURING PREREQUISITES              |"
echo "========================================================"
echo ""

START="$(date +%s)"

START="$(date +%s)"
# Make sure the preview features are registered
echo "Making sure that the features are registered"
az extension add --upgrade --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview" -o none

az provider register --namespace Microsoft.ContainerService -o none

echo ""
echo "========================================================"
echo "|                CREATING RESOURCE GROUP               |"
echo "========================================================"
echo ""

echo "Creating resource group ${CLUSTER_RG} in ${LOCATION}"
az group create -n ${CLUSTER_RG} -l ${LOCATION}


# Create AKS cluster with the required add-ons and configuration
echo "Creating an AKS Automatic cluster ${CLUSTER_NAME} with Kubernetes version ${K8S_VERSION}"
az aks create -n ${CLUSTER_NAME} -g ${CLUSTER_RG} \
--sku Automatic \
--location ${LOCATION} \
--kubernetes-version ${LATEST_K8S_VERSION}

# Wait until the provisioning state of the cluster is not updating
echo "Waiting for the cluster to be ready"
while [[ "$(az aks show -n ${CLUSTER_NAME} -g ${CLUSTER_RG} --query 'provisioningState' -o tsv)" == "Updating" ]]; do
    sleep 10
done

echo ""
echo "========================================================"
echo "|                    FINISHING UP                      |"
echo "========================================================"
echo ""

# Retrieve AKS cluster credentials
echo "Retrieving the Azure Kubernetes Service cluster credentials"
az aks get-credentials -n ${CLUSTER_NAME} -g ${CLUSTER_RG}

END="$(date +%s)"
DURATION=$[ ${END} - ${START} ]

echo ""
echo "========================================================"
echo "|                   SETUP COMPLETED                    |"
echo "========================================================"
echo ""
echo "Total time elapsed: $(( DURATION / 60 )) minutes"

echo ""
echo "========================================================"
echo "|               DEPLOYING THE APPLICATION              |"
echo "========================================================"
echo ""

# Apply Kubernetes manifests
kubectl apply -f nodepool-default.yaml
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml
kubectl apply -f pdb.yaml

echo ""
echo "========================================================"
echo "|                GETTING THE ENDPOINTS                 |"
echo "========================================================"
echo ""
SERVICE_IP=""
echo "Waiting for the service to get an IP address"
while [ -z $SERVICE_IP ]
do
    SERVICE_IP=$(kubectl get service serverloader --namespace=test -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    sleep 5
done

echo ""
echo "========================================================"
echo "|                OBSERVE THE COMPONENTS                |"
echo "========================================================"
echo ""
echo "Check node claims"
echo "kubectl get nodeclaims -o wide -w"
echo ""
echo "Wait for the deployment to be available"
echo "kubectl get deployment serverloader -n test -w"
echo ""

echo ""
echo "========================================================"
echo "|                 TEST THE APPLICATION                 |"
echo "========================================================"
echo ""
echo "curl -k http://${SERVICE_IP}/workout"
echo "curl -k http://${SERVICE_IP}/metrics"
echo "curl -k http://${SERVICE_IP}/stats"

echo ""
echo "========================================================"
echo "|                    RUN A LOAD TEST                   |"
echo "========================================================"
echo ""
echo "hey -n 240000 -c 300 http://${SERVICE_IP}/workout"

echo "AKS cluster and resources have been deployed successfully."
