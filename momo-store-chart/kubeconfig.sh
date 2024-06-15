#!/bin/bash

# Удаляем старый конфиг
echo "0. Удаляем старый конфиг ~/.kube/config"
rm -f ~/.kube/config

# Вставляем ID и добавляем CLUSTER_ID в переменную окружения
echo "1. Вставляем ID и добавляем CLUSTER_ID в переменную окружения"
export CLUSTER_ID=$(yc managed-kubernetes cluster list --format json | jq -r '.[] | select(.name=="sharuman-k8s-cluster") | .id')
echo "CLUSTER_ID is $CLUSTER_ID"

# Получаем учетные данные кластера
echo "2. Получаем учетные данные кластера"
yc managed-kubernetes cluster get-credentials $CLUSTER_ID --external --force --kubeconfig=$KUBECONFIG_PATH
if [ $? -ne 0 ]; then
  echo "Ошибка получения учетных данных кластера"
  exit 1
fi

# Проверка содержимого kubeconfig
echo "3. Проверка содержимого kubeconfig"
cat $KUBECONFIG_PATH

# Исправление пути к yc в kubeconfig
echo "3.1 Исправление пути к yc в kubeconfig"
sed -i 's|/home/student/yandex-cloud/bin/yc|/root/yandex-cloud/bin/yc|g' $KUBECONFIG_PATH

# Проверка содержимого kubeconfig после исправления пути
echo "3.2 Проверка содержимого kubeconfig после исправления пути"
cat $KUBECONFIG_PATH

# Получаем сертификат
echo "4. Получаем сертификат"
CERT_CONTENT=$(yc managed-kubernetes cluster get --id $CLUSTER_ID --format json | jq -r .master.master_auth.cluster_ca_certificate | base64 -w 0)

# Подготавливаем токен
echo "5. Подготавливаем токен"
SA_TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep admin-user-token | awk '{print $1}') -o json | jq -r .data.token | base64 -d)

# Получаем IP-адрес кластера
echo "6. Получаем IP-адрес кластера"
MASTER_ENDPOINT=$(yc managed-kubernetes cluster get --id $CLUSTER_ID --format json | jq -r .master.endpoints.external_v4_endpoint)

# Настройка kubeconfig
echo "7. Настройка kubeconfig"
kubectl config set-cluster sharuman-k8s-cluster --certificate-authority=/dev/null --server=$MASTER_ENDPOINT --kubeconfig=test.kubeconfig

# Замена пути сертификата на сертификатные данные
sed -i "s#certificate-authority: /dev/null#certificate-authority-data: ${CERT_CONTENT}#" test.kubeconfig

# Добавляем токен к файлу
kubectl config set-credentials admin-user --token=$SA_TOKEN --kubeconfig=test.kubeconfig

# Добавляем инфу о контексте
kubectl config set-context default --cluster=sharuman-k8s-cluster --user=admin-user --kubeconfig=test.kubeconfig

# Устанавливаем контекст по умолчанию
kubectl config use-context default --kubeconfig=test.kubeconfig

# Перемещение нового конфигурационного файла
echo "8. Перемещение нового конфигурационного файла"
mv test.kubeconfig $KUBECONFIG_PATH

# Проверка конечного содержимого kubeconfig
echo "9. Проверка конечного содержимого kubeconfig"
cat $KUBECONFIG_PATH
