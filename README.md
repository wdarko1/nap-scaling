# Azure Kubernetes Service (AKS) scaling demo using Node Auto-provisioning

## Components

1. Node Auto Provisioning (NAP) with a default NodePool

File list
- basic.yaml
- basic-deploy.yaml
- singlenode.yaml
- basic-rightsizing.yaml


## Setup

1. Clone the repository locally.
1. Login using `az login`.
1. Make sure `kubectl` is installed. You can install using `az aks install-cli`. 
1. Install `K9s` and `aks-node-viewer`. 


### Install Utilities

Use the below command to install `k9s`, and `aks-node-viewer` all used for this workshop to view state changes and deploy of nodes and pods. aks-node-viewer also provides an estimate of cost for provisioned nodes. See the install steps below:

```bash
cd ~/environment/karpenter/bin

# k9s - terminal UI to interact with the Kubernetes clusters
wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_Linux_amd64.tar.gz -O ~/environment/karpenter/bin/k9s.tar.gz
tar -xf k9s.tar.gz

# aks-node-viewer - used for tracking price, and other metrics of nodes
wget https://github.com/Azure/aks-node-viewer/releases/download/v0.0.2-alpha/aks-node-viewer_Linux_x86_64 -O ~/environment/karpenter/bin/aks-node-viewer
chmod +x ~/environment/karpenter/bin/aks-node-viewer
```


## Create Demo Cluster with NAP Enabled

Set Variables
Enter the below into Azure CLI to set your variables.
```
export CLUSTER_NAME=karpenter
export RG=karpenter
export LOCATION=westus2
```

Create Resource Group

```
az group create --name ${RG} --location ${LOCATION}
```
Create Cluster
```
az aks create --name $CLUSTER_NAME --resource-group $RG --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium --generate-ssh-keys
```

Confirm Credentials
```
az aks get-credentials --name $CLUSTER_NAME --resource-group $RG 
```

_Note: The creation of the cluster will result in system node pools and system pods. This should include approximately 3 VMSS system nodes, and a number of pods._

Deploy basic NodePool Config file
```
kubectl apply -f basic.yaml
```

You should see the following as the output
```
nodepool.karpenter.sh/default configured
aksnodeclass.karpenter.azure.com/default configured
```

View System Resources in K9s
```
k9s -n all
```

- view nodes in k9s
k9s -n nodes
:nodes

- view pods in k9s
:pods

- exit
crtl + c

Create namespace for application
```
kubectl create namespace workshop
```

You should see the following as the output:
```
namespace/workshop created
```

Deploy basic application 
```
kubectl apply -f basic-deploy.yaml
```
You should see the following as the output
```
deployment.apps/inflate created
```

Scale application to 5 replicas (pods)
```
kubectl scale deployment -n workshop inflate --replicas 5
```
You should see the following as the output
```
deployment.apps/inflate scaled
```

**Clean Up and Delete Deployment**
Cleanup: Remove Nodepool, AKSNodeClass, and Application

```
kubectl delete deployment -n workshop inflate
kubectl delete nodepool.karpenter.sh default
kubectl delete aksnodeclass default
```

Output: 
```
deployment.apps "inflate" deleted
nodepool.karpenter.sh "default" deleted
aksnodeclass.karpenter.azure.com "default" deleted
```


## Single Consolidation Demo 
In the next portion of this demo, we will showcase the concept of Consolidation, which is the primary method for NAP to perform node disruption. When the workloads on your nodes scale down, Node autoprovision uses disruption rules on the Node Pool specification to decide when and how to remove those nodes and potentially reschedule your workloads to be more efficient. This is primarily done through Consolidation, which deletes or replaces nodes to bin-pack your pods in an optimal configuration. The state-based consideration uses `ConsolidationPolicy` such as `WhenUnderUtilized`, `WhenEmpty`, or `WhenEmptyOrUnderUtilized` to trigger Consolidation. `consolidateAfter` is a time-based condition that can be set to allow buffer time between actions.

Deploy NodePool for Consolidation demo
```
kubectl apply -f singlenode.yaml
```

Output
```
nodepool.karpenter.sh/default created
aksnodeclass.karpenter.azure.com/default created
```

**Deploy sample application for single node consolidation**

Let's deploy the application. You can see that we are specifying below in the NodePool spec:
- The container resource request as "1" CPU and "1Gi" memory.
- We will also set the pod replicas to 8

```
kubectl apply -f basic-rightsizing.yaml
```

Output
```
deployment.apps/inflate configured
```


Confirm the deployment in k9s
```
k9s -n workshop
```

Alternative view of pods/nodes
```
kubectl -n workshop get pods -o wide
kubectl get nodeclaims
```

what you should see here is 8 pod replicas of the application, which should be in 2 user nodes.



Scale Application down to 4 replicas
```
kubectl scale deployment -n workshop inflate --replicas 4
```

Confirm the deployment in k9s
```
k9s -n workshop
```

Alternative view of pods/nodes
```
kubectl -n workshop get pods -o wide
kubectl get nodeclaims



