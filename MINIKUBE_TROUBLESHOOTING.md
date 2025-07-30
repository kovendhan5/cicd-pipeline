# Minikube Troubleshooting Guide

## Current Issues and Solutions

### Issue 1: kubectl configuration problems

**Symptoms:**

- `kubectl get nodes` returns configuration errors
- "kubeconfig: Misconfigured" in minikube status
- Certificate file not found errors

**Solutions:**

1. **Quick Fix:**

   ```cmd
   minikube update-context
   kubectl cluster-info
   ```

2. **If quick fix doesn't work:**

   ```cmd
   scripts\minikube-complete-reset.bat
   ```

3. **Manual fix:**
   ```cmd
   minikube delete
   minikube start --driver=docker --cpus=2 --memory=4096
   minikube update-context
   ```

### Issue 2: Memory constraints

**Your system has limited memory (7756MB available)**

**Solutions:**

- Use our optimized scripts that automatically reduce memory usage
- Close other applications before starting Minikube
- Increase Docker Desktop memory allocation:
  1. Open Docker Desktop
  2. Settings → Resources → Advanced
  3. Increase Memory to 8GB if possible

### Issue 3: Network connectivity warnings

**Symptoms:**

- "Failing to connect to https://registry.k8s.io/"
- Image pull warnings

**Solutions:**

- These are warnings, not errors - Minikube will work
- For production use, configure proxy if needed
- Use local image builds (which we do)

## Current Working Commands

### Start Minikube (optimized for your system):

```cmd
scripts\minikube-manage.bat start
```

### Check status:

```cmd
scripts\minikube-manage.bat status
```

### Complete reset (if needed):

```cmd
scripts\minikube-complete-reset.bat
```

### Build and deploy app:

```cmd
scripts\minikube-manage.bat build
scripts\minikube-manage.bat deploy
```

## Next Steps

1. Run the complete reset script to get a clean start
2. Build your application image
3. Deploy to Minikube
4. Test the API endpoints

## Files Created for Your Environment

- `scripts\minikube-manage.bat` - Main management script
- `scripts\minikube-recovery-light.bat` - Lightweight setup
- `scripts\minikube-complete-reset.bat` - Complete reset
- `scripts\minikube-quickfix.bat` - Quick troubleshooting
- `scripts\docker-config-helper.bat` - Docker configuration help
