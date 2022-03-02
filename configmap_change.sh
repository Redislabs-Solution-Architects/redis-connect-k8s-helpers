#!/bin/bash

###
#  Start out in a directory with your Redis Connect deployment manifests
#  This script:
#    1. switches directory to where your Redis Connect config files are
#    2. deletes and then recreates a configmap based on up to date config files
#    3. switches back to your original directory
#    4. Deletes any Redis Connect deployments
#    5. Re-creates the Redis Connect stage and start deployments
#    6. Watches the pods being terminated and created
#
#  Improvements:
#    * Add a few commands to retrieve the latest pods and tail their logs
### 

pushd .; 
cd ../demo/config/samples/postgres; 
kubectl delete configmap/redis-connect-postgres-config;
kubectl create configmap redis-connect-postgres-config \
  --from-file=JobConfig.yml=JobConfig.yml \
  --from-file=JobManager.yml=JobManager.yml \
  --from-file=env.yml=env.yml \
  --from-file=Setup.yml=Setup.yml \
  --from-file=mapper1.yml=mappers/mapper1.yml 
  # \
  # --from-file=logback.xml=../../logback.xml
popd
kubectl delete -f vault/redis-connect-postgres-stage.yaml
kubectl delete -f vault/redis-connect-postgres-start.yaml
sleep 5s
kubectl apply -f vault/redis-connect-postgres-stage.yaml
sleep 10s
kubectl apply -f vault/redis-connect-postgres-start.yaml
kubectl get po -w
