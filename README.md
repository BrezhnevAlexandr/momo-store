# Momo Store aka Пельменная №2

<img width="900" alt="image" src="https://user-images.githubusercontent.com/9394918/167876466-2c530828-d658-4efe-9064-825626cc6db5.png">


##Kluster k8s для развертывания в YandexCloud

Кластер описан в terraform
Во время запуска кластера  из gitlab
Для запуска необходимо прописать следующие переменные в гилабе:
AWS_ACCESS_KEY - ID  ключа к S3
AWS_SECRET_ACCESS - Ключ к S3
YC_TOKEN - IAM токен
YC_TOK -  токен доступа до личного облака
YC_CLOUD_ID - ID облака
YC_FOLDER_ID -  ID папки, где будет размещен кластер 

## Frontend
Версию фронтенда необходимо указать в переменой GitLab NEXT_VERSION_F.
Рекомендуется указать в виде трехзначного числа, например начать с 001
Сборка образа проходит с помощью  Kaniko, отправка Crane

## Backend
Версию бэкенда необходимо указать в переменой GitLab NEXT_VERSION_B.
Рекомендуется указать в виде трехзначного числа, например начать с 001
Сборка образа проходит с помощью  Kaniko, отправка Crane

## Helm
Перед развертыванием необходимо выполнить сборку k8s кластера
Либо поставить таймер sleep 1200, примерно 20 минут уходит на сборку кластера.
Для отправки архива чартов helm в nexus понадобится определить следующие переменные в gitlab:
NEXUS_HELM_REPO - адрес репозитория в nexus где будет гранится архив чартов
NEXUS_REPO_PASS - пароль nexus
NEXUS_REPO_USER - логин nexus
YC_TOK -  токен доступа до личного облака
YC_CLOUD_ID - ID облака
YC_FOLDER_ID -  ID папки, где будет размещен кластер 

.gitlab-ci.yml в momo-store-chart делает следующее:
1. Архивирует чарт и отправляет в nexus
2. устанавливает kubekonfig в среду где производится развертывание
3. Устанавливает Ingress-nginx
4. Устанавливает вертикальное автомасштабирование для backend
5. Устанавливает cert-manager для добавления сертификатов Let's Encrypt
6. Устанавливает следующие микросервисы из чарта momo-store:
    - frontend momo-store, в котором содержится ингресс на следуюхие сайты:
        * momo-store-your-domain.ru
        * alertmanager.your-domain.ru
        * grafana.momo-store-your-domain.ru
        * monitoring.momo-store-ayour-domain.ru
    - установка сертификатов на перечисленые сайты
    - backend momo-store
    - alertmanager
    - grafana (по умолчанию admin / admin)
    - prometheus
    - loki
 После установки, прометеус и loki сразу готов.
 Необходимо только настроить grafana на получение данных с loki и прометеус
 Для получения метрик прометеусом в grafana нужно добавсить следующие запросы в grafana при создании дашборда:
     - sum(rate(dumplings_listing_count[1d])) by (id)  - счетчик показа страниц с пельменями
     - sum(rate(requests_count{handler!~"/metrics|/health"}[5m])) -  трафик успешных запросов
     - rate(orders_count{handler!~"/metrics|/health"}[1d])- счетчик заказов
     - задержка ответов от страниц:
             + histogram_quantile(0.99, sum(rate(response_timing_ms_bucket{handler="/products/"}[1h])) by (le)) 
             + histogram_quantile(0.99, sum(rate(response_timing_ms_bucket{handler="/auth/whoami/"}[1h])) by (le))
             + histogram_quantile(0.99, sum(rate(response_timing_ms_bucket{handler="/categories/"}[1h])) by (le))   

Настроить alertmanager на получение сообщений в телеграм, для этого поменять в values.yaml id для телеграма.
Так же в charts/prometheus/rules/momo-store.yaml настроить правил получения оповещений, исходя запросов для метрик описаных выше.