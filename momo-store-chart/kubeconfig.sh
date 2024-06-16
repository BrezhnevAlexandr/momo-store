#!/bin/bash
echo "0. Удаляем старый конфиг ~/.kube/config"
rm ~/.kube/config
echo "1. Вставляем ID и добавляем CLUSTER_ID в переменную окружения"
echo "выполнение команды yc managed-kubernetes cluster get-credentials sharuman-k8s-cluster --external --force"
yc managed-kubernetes cluster get-credentials sharuman-k8s-cluster --external --force
echo "Результат выполнения предыдущей команды и факт подтверждения что yc установлен и работает"
 
mkdir testconfig
cd testconfig/

export CLUSTER_ID=$(yc managed-kubernetes cluster list --format json | jq -r '.[] | select(.name=="sharuman-k8s-cluster") | .id')
echo "CLUSTER_ID is $CLUSTER_ID"

echo "2. Получаем сертификат..."
yc managed-kubernetes cluster get --id $CLUSTER_ID --format json | \
  jq -r .master.master_auth.cluster_ca_certificate | \
  awk '{gsub(/\\n/,"\n")}1' > ca.pem

CERT_CONTENT=$(base64 -w 0 ca.pem)

echo "3. Подготавливаем токен" 
SA_TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get secret | \
  grep admin-user-token | \
  awk '{print $1}') -o json | \
  jq -r .data.token | \
  base64 -d)
  
echo "4. Получаем IP-адрес кластера"
MASTER_ENDPOINT=$(yc managed-kubernetes cluster get --id $CLUSTER_ID \
  --format json | \
  jq -r .master.endpoints.external_v4_endpoint)
  
echo "5. Добавляем файл конфигурации"
kubectl config set-cluster sharuman-k8s-cluster \
  --certificate-authority=/dev/null \
  --server=$MASTER_ENDPOINT \
  --kubeconfig=test.kubeconfig

sed -i "s#certificate-authority: /dev/null#certificate-authority-data: ${CERT_CONTENT}#" test.kubeconfig
  
echo "6. Добавляем токен к файлу"
kubectl config set-credentials admin-user \
  --token=$SA_TOKEN \
  --kubeconfig=test.kubeconfig
  
echo "7. Добавляем инфу о контексте"
kubectl config set-context default \
  --cluster=sharuman-k8s-cluster \
  --user=admin-user \
  --kubeconfig=test.kubeconfig
  
  
kubectl config use-context default \
  --kubeconfig=test.kubeconfig
echo "8. Прибираемся за собой и меняем файл. Теперь доступен новый конфиг:"
rm ~/.kube/config
mv test.kubeconfig ~/.kube/config
cd ..
rm -rf testconfig/

