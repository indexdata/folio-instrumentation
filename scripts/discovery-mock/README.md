# discovery mock
Use this script to simulate activity from a discovery system. An infinite loop will pick random instances and resolve all associated holdings and items. Number of instances resolved and frequency can be adjusted by changing the constants in the script.

## Requirements
Set OKAPI, TENANT, USERNAME, and PASSWORD environment variables.

To run with python:
```
# environment variables described above must be set
pip install -r requirements.txt
python dummy.py
```

OKAPI=http(s)://your_okapi_url TENANT=your_tenant USERNAME=your_tenant_user PASSWORD=your_tenant_password discover-mock`
To run with docker: `docker run -e OKAPI=http(s)://your_okapi_url -e TENANT=your_tenant -e USERNAME=your_tenant_user -e PASSWORD=your_tenant_password discover-mock`

## Example kubernetes deployment manifest
```
# -*- mode: yaml; -*-
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "mock-discovery"
  labels:
    app: "mock-discovery"
  namespace: "debug"
spec:
  selector:
    matchLabels:
      app: "mock-discovery"
  replicas: 1
  template:
    metadata:
      labels:
        app: "mock-discovery"
    spec:
      containers:
        - name: "mock-discovery"
          image: "your_docker_registry/discovery-mock:latest"
          imagePullPolicy: Always
          env:
            - name: OKAPI
              value: "http(s)://your_okapi_url"
            - name: TENANT
              value: "your_tenant"
            - name: USERNAME
              value: "your_tenant_user"
            - name: PASSWORD
              value: "your_tenant_password"
```
