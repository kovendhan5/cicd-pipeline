#!/bin/bash

# Minikube management script
set -e

COMMAND=${1:-help}

case $COMMAND in
    start)
        echo "🚀 Starting Minikube cluster..."
        minikube start --driver=docker --cpus=4 --memory=8192
        ;;
    
    stop)
        echo "🛑 Stopping Minikube cluster..."
        minikube stop
        ;;
    
    delete)
        echo "🗑️ Deleting Minikube cluster..."
        minikube delete
        ;;
    
    status)
        echo "📊 Minikube status:"
        minikube status
        echo ""
        echo "📦 Cluster info:"
        kubectl cluster-info
        echo ""
        echo "📋 Nodes:"
        kubectl get nodes
        ;;
    
    dashboard)
        echo "📊 Opening Kubernetes dashboard..."
        minikube dashboard
        ;;
    
    tunnel)
        echo "🌐 Starting Minikube tunnel (requires sudo)..."
        echo "This will expose LoadBalancer services"
        minikube tunnel
        ;;
    
    ip)
        echo "🌍 Minikube IP address:"
        minikube ip
        ;;
    
    services)
        echo "🔗 Available services:"
        minikube service list
        ;;
    
    logs)
        echo "📜 Minikube logs:"
        minikube logs
        ;;
    
    ssh)
        echo "🔧 SSH into Minikube node..."
        minikube ssh
        ;;
    
    docker-env)
        echo "🐳 Configure Docker to use Minikube's Docker daemon:"
        echo "Run the following command:"
        echo "eval \$(minikube docker-env)"
        ;;
    
    reset-docker)
        echo "🔄 Reset Docker environment to use system Docker:"
        echo "Run the following command:"
        echo "eval \$(minikube docker-env -u)"
        ;;
    
    build)
        echo "🏗️ Building application in Minikube Docker environment..."
        eval $(minikube docker-env)
        docker build -t cicd-pipeline:latest .
        echo "✅ Image built successfully in Minikube"
        ;;
    
    deploy)
        echo "🚀 Deploying application to Minikube..."
        kubectl apply -f k8s/minikube-deployment.yaml
        echo "⏳ Waiting for deployment..."
        kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n cicd-pipeline
        echo "✅ Deployment completed"
        ;;
    
    url)
        echo "🌐 Getting service URL..."
        SERVICE_URL=$(minikube service cicd-pipeline-service --url -n cicd-pipeline)
        echo "API URL: $SERVICE_URL"
        echo "API Docs: $SERVICE_URL/docs"
        echo "Health Check: $SERVICE_URL/health"
        ;;
    
    port-forward)
        PORT=${2:-8080}
        echo "🔗 Port forwarding on port $PORT..."
        kubectl port-forward -n cicd-pipeline service/cicd-pipeline-service $PORT:80
        ;;
    
    logs-app)
        echo "📜 Application logs:"
        kubectl logs -n cicd-pipeline deployment/cicd-pipeline-app -f
        ;;
    
    scale)
        REPLICAS=${2:-3}
        echo "📈 Scaling application to $REPLICAS replicas..."
        kubectl scale deployment cicd-pipeline-app --replicas=$REPLICAS -n cicd-pipeline
        ;;
    
    restart)
        echo "🔄 Restarting application..."
        kubectl rollout restart deployment/cicd-pipeline-app -n cicd-pipeline
        kubectl rollout status deployment/cicd-pipeline-app -n cicd-pipeline
        ;;
    
    clean)
        echo "🧹 Cleaning up deployments..."
        kubectl delete -f k8s/minikube-deployment.yaml --ignore-not-found=true
        kubectl delete namespace cicd-pipeline --ignore-not-found=true
        ;;
    
    addons)
        echo "🔌 Managing addons..."
        case ${2:-list} in
            list)
                minikube addons list
                ;;
            enable)
                ADDON=${3:-ingress}
                minikube addons enable $ADDON
                ;;
            disable)
                ADDON=${3:-ingress}
                minikube addons disable $ADDON
                ;;
            *)
                echo "Usage: $0 addons [list|enable|disable] [addon-name]"
                ;;
        esac
        ;;
    
    help|*)
        echo "🔧 Minikube Management Script"
        echo ""
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Cluster Management:"
        echo "  start         Start Minikube cluster"
        echo "  stop          Stop Minikube cluster"
        echo "  delete        Delete Minikube cluster"
        echo "  status        Show cluster status"
        echo "  restart       Restart the application"
        echo ""
        echo "Application Management:"
        echo "  build         Build application image"
        echo "  deploy        Deploy application"
        echo "  clean         Clean up deployments"
        echo "  scale [n]     Scale to n replicas (default: 3)"
        echo ""
        echo "Access & Networking:"
        echo "  url           Get service URLs"
        echo "  port-forward [port]  Port forward to local port (default: 8080)"
        echo "  ip            Show Minikube IP"
        echo "  services      List all services"
        echo "  tunnel        Start LoadBalancer tunnel"
        echo ""
        echo "Monitoring & Debugging:"
        echo "  dashboard     Open Kubernetes dashboard"
        echo "  logs          Show Minikube logs"
        echo "  logs-app      Show application logs"
        echo "  ssh           SSH into Minikube node"
        echo ""
        echo "Docker Environment:"
        echo "  docker-env    Configure Docker for Minikube"
        echo "  reset-docker  Reset Docker to system"
        echo ""
        echo "Add-ons:"
        echo "  addons list           List available addons"
        echo "  addons enable [name]  Enable addon"
        echo "  addons disable [name] Disable addon"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 build && $0 deploy"
        echo "  $0 port-forward 8080"
        echo "  $0 scale 5"
        ;;
esac
