# Azure Kubernetes Service (AKS) scaling demo using AKS Automatic + Spot instances

## Components

1. AKS Automatic cluster
1. Node Auto Provisioning (NAP) with a spot NodePool

## Setup

1. Clone the repository locally.
1. Login using `az login`.
1. Make sure `kubectl` is installed. You can install using `az aks install-cli`. 
1. Make sure `hey` is [installed](https://github.com/rakyll/hey) if you want to use it for the load test.
1. Run `./setup.sh` in a Bash shell, preferably in [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install).


## Exposed endpoints

1. `/workout`: generates long strings and stores them in memory.
1. `/metrics`: Prometheus metrics.
1. `/stats`: .NET stats.

## Test

1. Run a load test against the `/workout` endpoint. You can use [Azure Load Testing](https://learn.microsoft.com/en-us/azure/load-testing/quickstart-create-and-run-load-test?tabs=portal) or `hey`.
1. Observe Node Auto Provisioning adding more nodes to the cluster.
    ```bash
    kubectl get events -n test --field-selector source=karpenter -w
    ```
1. Observe the node claims being created
    ```bash
    kubectl get nodeclaims
    ```