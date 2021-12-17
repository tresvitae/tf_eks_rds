# tf_eks_rds

source: [url](https://dev.to/stack-labs/securing-the-connectivity-between-amazon-eks-and-amazon-rds-part-1-527o)

## Create metabase db on RDS instance:
```
PGPASSWORD=$(terraform output rds-password) psql --host $(terraform output public-rds-endpoint) --port 5432 --user $(terraform output rds-username) --dbname postgres
CREATE USER metabase;
GRANT rds_iam TO metabase;
CREATE DATABASE metabase;
GRANT ALL ON DATABASE metabase TO metabase;
```

## Grab EKS config
`aws eks --region ... update-kubeconfig --name ....`
`kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2`

## Update CNI version
Change version if necessary
```
curl -o aws-k8s-cni.yaml https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v1.9/aws-k8s-cni.yaml
sed -i "s/us-west-2/eu-west-1/g" aws-k8s-cni.yaml
kubectl apply -f aws-k8s-cni.yaml
```

`kubectl set env daemonset -n kube-system aws-node ENABLE_POD_ENI=true`

kubectl get nodes -o wide -l vpc.amazonaws.com/has-trunk-attached=true

## Generate DB auth token
METABASE_PWD=$(aws rds generate-db-auth-token --hostname $(terraform output private-rds-endpoint) --port 5432 --username metabase --region $REGION)
METABASE_PWD=$(echo -n $METABASE_PWD | base64 -w 0 )
sed -i "s/<MB_DB_PASS>/$METABASE_PWD/g" database-secret.patch.yaml
sed -i "s/<POD_SECURITY_GROUP_ID>/$(terraform output sg-rds-access)/g; s/<EKS_CLUSTER_SECURITY_GROUP_ID>/$(terraform output sg-eks-cluster)/g" security-group-policy.patch.yaml
sed -i "s,<RDS_ACCESS_ROLE_ARN>,$(terraform output rds-access-role-arn),g" service-account.patch.yaml
sed -i "s/<MB_DB_HOST>/$(terraform output private-rds-endpoint)/g" deployment.patch.yaml

## Run edited manifests
kubectl create namespace metabase
kubectl config set-context --current --namespace=metabase
kustomize build . | kubectl apply -f -

## Check
kubectl get pods
kubectl describe pods meta-...
kubectl logs meta-...

## Delete
kubectl delete -f security-group-policy.patch.yaml
kubectl delete -f deployment.patch.yaml
kubectl apply -f deployment.patch.yaml

kubectl annotate sa metabase eks.amazonaws.com/role-arn-
kubectl apply -f security-group-policy.patch.yaml
kubectl delete -f deployment.patch.yaml
kubectl apply -f deployment.patch.yaml
kustomize build . | kubectl delete -f -
