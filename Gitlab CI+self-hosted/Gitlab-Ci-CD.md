for quick start:
>systemctl start nginx
   systemctl start gitlab-runner
   docker-compose up -d in /home/stephenj/gitlab-selfhosted


FOR SELF-HOSTED GITLAB:
```
version: '3'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    restart: on-failure
    hostname: 'localhost'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost:8929'
    ports:
      - '8929:8929'
      - '2289:22'  #для ssh
    volumes:
      - ./config:/etc/gitlab
      - ./logs:/var/log/gitlab
      - ./data:/var/opt/gitlab
```

Когда ставишь self-hosted гитлаб, его можно по разному настроить и у меня была такая тема, что я ставлю его в контейнере и админа изначально там нет и выделеной учетки тоже, так что придется поадминить в этом моменте. Но если ставишь на тачку, вроде как есть аккаунт для админа.
![[Pasted image 20250802211151.png]]
💡 Вместо `find_by_username` можно использовать `find_by_email('your@email.com')`, если не помнишь username.

Рекомендация к установке раннера на гитлабе(ставится как сервис-служба):
>	curl -L --output gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
>	sudo mv gitlab-runner /usr/local/bin/gitlab-runner
>	sudo chmod +x /usr/local/bin/gitlab-runner
>	sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
>	sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
>	sudo gitlab-runner start

Еще - если раннер свой, не настроенный, то нужно смотреть запускать ли ему теггированные джобы или нет.(можно настроить и в графическом варианте и в конфиге)



Это конфиг ранера который настраивается в сервисе `cat /etc/systemd/system/gitlab-runner.service`, там вообще много чего настраивается - какая директория будет начальной, какой и откуда брать конфиг для запуска и тд.
![[Pasted image 20250806173557.png]]
>nano /home/stephenj/.gitlab-runner/config.toml
```
concurrent = 1
check_interval = 0

[[runners]]
  name = "docker-dind-runner"
  url = "http://host.docker.internal:8929"
  token = ""
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_cache = false
    volumes = [
      "/cache",
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
    shm_size = 0
  [runners.cache]
    Type = "local"

```
Проблема еще в том, что кофиг может быть стоит поменять в разных ситуациях, поменять dind, cache и тд.(смотреть по ситуации)


Эти команды нужны, я так понял если ты сам хочешь с тачки запускать раннер, то придется воспользоваться этим.
>gitlab-runner restart
>gitlab-runner run
>gitlab-runner verify


Тут архитектура такая:
/etc/nginx/nginx.conf - описывает сертификаты, какие страницы будут показываться по порту.
Допустим у меня есть default в sites-available который принимает html страницу по адресу /var/www/html, я там все закоментил и дал ему другую страницу - gitlab-proxy которая проксирует запросы с одного домена на другой.

proxy_pass
```
/etc/nginx/sites-available/gitlab-proxy                                                 
server {
    listen 81;

    location / {
        proxy_pass http://127.0.0.1:8929;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```



# Рабочий Dind 

- Запушить завтра

Короче несколько моментов 

>изучить передачу сокетов(хотя проблема в wsl)
>при dind ничего на хосте выводиться не будет, все работает только в контейнере и допустим curl -v http://localhost будет работать только из контейнера 
>мб дополню

- Gitlab-runner fiction 
-> gitlab-runner --debug run
-> gitlab-runner restart(systemctl)

>gitlab-ci.yml
```
stages:
  - setup
  - proxy
  - test

run-webpage:
  stage: setup
  image: docker:24.0
  services:
    - name: docker:dind
      alias: docker
      command: ["--debug"]
  variables:
    DOCKER_HOST: unix:///var/run/docker.sock
    DOCKER_TLS_CERTDIR: "/certs"
  tags:
    - dind
  script:
    - docker network ls --format '{{.Name}}' | grep -w test-net || docker network create test-net
    - docker run -d --name webpage --network test-net nginxdemos/hello

run-nginx:
  stage: proxy
  image: docker:24.0
  services:
    - name: docker:dind
      alias: docker
      command: ["--debug"]
  variables:
    DOCKER_HOST: unix:///var/run/docker.sock
    DOCKER_TLS_CERTDIR: "/certs"
  tags:
    - dind
  needs: [run-webpage]
  script:
    - docker rm -f nginx 2>/dev/null || true
    - docker run -d --name nginx --network test-net -p 8080:80 nginx 
    - |
      docker exec nginx sh -c 'cat > /etc/nginx/conf.d/default.conf' <<EOF
      server {
          listen 80;
          location / {
              proxy_pass http://webpage;
          }
      }
      EOF
    - sleep 5
    - docker exec nginx nginx -s reload

hello-world:
  stage: test
  image: docker:24.0
  services:
    - name: docker:dind
      alias: docker
      command: ["--debug"]
  variables:
    DOCKER_HOST: unix:///var/run/docker.sock
    DOCKER_TLS_CERTDIR: "/certs"
  tags:
    - dind
  script:
    - docker info
    - docker run --rm hello-world
```

>/etc/gitlab-runner/conf.toml
Острые моменты:
PRIVILEGED = TRUE; 
монтируем сокет через volumes
выбираем image при регистрации executor'a docker:dind(в моем случае)
запускать все при gitlab-runner --debug run, иначе попадаем под ограничения(если все криво настроено) и вылетаем с ошибкой

```
concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "dind"
  url = "https://git.21-school.ru"
  id = 17852
  token = ""
  token_obtained_at = 2025-08-08T10:29:11Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "docker:dind"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    pull_policy = "if-not-present"
    wait_for_services_timeout = 180
    volumes = ["/var/run/docker.sock:/var/run/docker.sock","/cache"]
    shm_size = 0
    network_mtu = 0
```

># cat /etc/nginx/conf.d/default.conf
```

server {
    listen 80;
    location / {
        proxy_pass http://webpage;
    }
}
```

Нужно дополнить удалением контейнеров и image конце/начале
![[Pasted image 20250809030842.png]]
![[Pasted image 20250809030906.png]]
![[Pasted image 20250809030948.png]]

если че вспомню дополню

[ссылка на gitlab](https://git.21-school.ru/students/DevOps_7.ID_1219717/stephenj/DevOps_7-1/-/pipelines)
(ссылка на github)[]


## cheatsheets
![[Pasted image 20250810003749.png]]


# Новый ci для более глубоких вещей
![[Pasted image 20250810222603.png]]

![[Pasted image 20250810234851.png]]


Настройки раннера остаются такими же, ЕДИНСТВЕННОЕ ЧТО МОЖНО СДЕЛАТЬ - добавить второй раннер(шелл) и запускать его для очистки контейнеров в конце, потому-что dind у меня имхо сдулся.

новый gitlab-ci.yml

```yml
stages:
  - setup
  - proxy
  - test
  - cleanup

variables:
  DOCKER_HOST: unix:///var/run/docker.sock
  DOCKER_TLS_CERTDIR: "/certs"
  NETWORK_NAME: "test-net"
  WEBPAGE_IMAGE: "nginxdemos/hello"
  NGINX_IMAGE: "nginx:alpine"

.docker_job: &docker_job
  image: docker:24.0
  services:
    - docker:dind
  tags:
    - dind

run-webpage:
  <<: *docker_job
  stage: setup
  script:
    - docker network create $NETWORK_NAME || true
    - docker run -d --name webpage --network $NETWORK_NAME $WEBPAGE_IMAGE
    - |
      timeout 30 sh -c '
        until docker inspect -f "{{.State.Running}}" webpage 2>/dev/null | grep -q "true"; do
          sleep 2
        done
      ' || { echo "Container webpage failed to start"; exit 1; }

run-nginx:
  <<: *docker_job
  stage: proxy
  needs: [run-webpage]
  script:
    - docker rm -f nginx 2>/dev/null || true
    - docker run -d --name nginx --network $NETWORK_NAME -p 8080:80 $NGINX_IMAGE 
    - |
      cat <<EOF | docker exec -i nginx sh -c 'cat > /etc/nginx/conf.d/default.conf'
      server {
          listen 80;
          location / {
              proxy_pass http://webpage;
          }
      }
      EOF
    - docker exec nginx nginx -s reload
    - |
      timeout 30 sh -c '
        until docker inspect -f "{{.State.Running}}" webpage 2>/dev/null | grep -q "true"; do
          sleep 2
        done
      ' || { echo "Container webpage failed to start"; exit 1; }

test-nginx-proxy:
  <<: *docker_job
  stage: test
  needs: [run-nginx]
  script:
    - apk add curl
    - curl -v http://webpage > curl_output.txt 2>&1
  artifacts:
    paths:
      - curl_output.txt
    when: on_success
    access: all
    expire_in: 1 hour


test-hello-world:
  <<: *docker_job
  stage: test
  script:
    - docker info
    - docker run --rm hello-world

cleanup:
  <<: *docker_job
  stage: cleanup
  when: always
  script:
    - docker rm -f webpage nginx || true
    - docker network rm $NETWORK_NAME || true
```

> можно еще вставить что-то по типу такого в конец

```yml
telegram_notify:
  stage: notify
  script:
    - |
      EMOJI="✅"
      if [ "$CI_JOB_STATUS" = "failed" ]; then
        EMOJI="❌"
      fi
      
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${EMOJI} Pipeline [#${CI_PIPELINE_ID}](${CI_PIPELINE_URL}) ${CI_JOB_STATUS}" \
        -d "parse_mode=MarkdownV2"
  rules:
    - when: always

```
