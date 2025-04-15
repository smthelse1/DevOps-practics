
Следую конспектам(), разберу каждый инструмент изоляции процессов([[ПРОЦЕССЫ]]): 

>- **chroot**

```sh
**[host shell]**

cd /tmp #tmp дериктория с временными файлами

mkdir malutka

which sh #т.к нам нужно изолированное простарнство с консолью, а консоль это bash, то нам нужно его скопировать(смонтировать в нашу будущую root папку под процесс)
cp --parents /usr/bin/sh malutka/ #which sh - поиск файлов bash, --paretns - копирование со всеми зависимостями
tree malutka/

ldd /usr/bin/sh #поиск дополнительных библиотек без коротых не работает bash

tar ch /lib/x86_64-linux-gnu/libc.so.6 /lib64/ld-linux-x86-64.so.2 | tar x -C malutka/ #т.к. это библиотеки мы их распаковываем сразу в нашу будущую среду

tree malutka/

chroot malutka/ sh #сам заход в процесс(изолированную среду)

**[container shell]**

ls #not working

**[host shell]**

mkdir malutka/bin #создадим дерикторию для программ

wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
#скачаем busybox- штука которая содержит в себе много утилит(cat, ls...)
chmod +x busybox

mv busybox malutka/bin/ #запихем 

chroot malutka/ busybox sh

**[container shell]**

bin/busybox --install -s #наша команда ls не работает просто так, нам нужно ее запускать от приложения /bin/busybox ls, скачиваем зависимости чтобы было легче
ls -al

ps #не работает, т.к. нет папки proc которая хранит инфу о всех процессах

mkdir /proc

mount -t proc none /proc #монтируем ее, none потому-что proc виртуальная

ps #succ
```

![[Pasted image 20250415191603.png]]![[Pasted image 20250415191846.png]]
![[Pasted image 20250415192529.png]]
![[Pasted image 20250415192544.png]]

- Так же накидал(xd) скрипт для автоматизации, будет вот [тут](

>- **unshare, namespaces**) 
```sh
**[host shell]**

unshare -mnp -f -R malutka --mount-proc busybox sh #создание изолированного процесса путем передачи процесса череpз unshare с namespace'ами mount, net и pid
**[container shell]**

ls -l /proc/$$/ns #два доллара значат-текующую обстановку(грубо)

ps aux
```
>![[Pasted image 20250415201430.png]]
- Так же есть еще namespac'ы, такие как: time, cgroups, pid, user, uts, ipc, net, mnt(mount)
![[Pasted image 20250415201601.png]]

>- **cgroups**

```sh
**[host shell]**

unshare --mount --uts --ipc --net --pid --fork -f -R malutka --mount-proc busybox sh #отсоединяем процесс 

**[container shell]**

ps aux

**[host shell]**

mkdir /sys/fs/cgroup/malutka #у меня не получилось, я чмо криворукое. sys/fs/cgroup
#read-only file system, ее можно перемонтировать в "read-write mount -o remount,ro(rw) /sys/fs/cgroup", но просто создать папку в сигруппах недостаточно, нужно же ее откуда-то скопировать с наполнением, вот тут и проблема

echo 524288 | tee /sys/fs/cgroup/malutka/memory.max #хотим ограничить наш контейнер 0,5Мб памяти

ps aux | grep busybox

echo '<MY_PID>' | tee /sys/fs/cgroup/malutka/cgroup.procs #записываем наш процесс в сигруппу для последующего контроля

**[container shell]**

sh -C 'a=""; while true; do a="$a A"; done' #баш-скрипт для нагрузки оперативы

**[host shell]**

dmesg | grep -i oom #в итоге псевдо-контейнер будет жить, а процесс баша помрет


"""> mkdir /sys/fs/cgroup/malutka
mkdir: cannot create directory ‘/sys/fs/cgroup/malutka’: Read-only file system
>mount -o remount,ro(rw) /sys/fs/cgroup
```

	- C хостовой системы баш скрипт будет запущен как дочерний процесс, OOM(out of memmory) придет за этим дочерним процессом и убьет его


> **runc** - Под докером сидит OCI(open container initiation) которая выполняет функции docker-rintime'a и спецификацию image который runtime считывает
> Так вот runx в linux это реализация этого OCI посредством одной утилиты

```sh
**[host shell]**

mkdir chillguy

cd chillguy

runc spec #это еще нужно скачать, при команле spec, runc создает config.json в котором полностью описывается как будет работать наш контейнер, неймспейсы, сигруппы, права и тд

less config.json

debootstrap --variant=minbase jammy rootfs (в видосе ставил еще iproute2, а продемонстрировать забыл...) #эта шутка скачивает файловую систему линукса, а именно UBUNTU 22.04, ее позывной jammy, эта строка эквивалентна как если бы мы скачали и запустили пустой контейнер с alpine, просто файловая система, ничего лишнего

ps o pid,netns,mntns,pidns, p $$ #вывод неймспейсом текущего окружения, тут PID не равен 1

runc run chillguy

**[container shell]**

ps o pid,netns,mntns,pidns, p $$ #а тут уже PID равен 1(новый дочерний процесс)

exit

**[host shell]**

cd rootfs/

ls
```

![[Pasted image 20250415214848.png]]

![[Pasted image 20250415215659.png]]


# Что изучить

можно подтянуть в целом знания линукса))
файловая система,  капабилити в конфиге контейнера:

 "capabilities": {
                        "bounding": [
                                "CAP_AUDIT_WRITE",
                                "CAP_KILL",
                                "CAP_NET_BIND_SERVICE"

Различия между Docker, containerd, CRI-O и runc [https://habr.com/ru/companies/domclick/articles/566224/](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqblEyMFp3NjlSeThHRHg5UFZ2dGpSSG8wTWVlUXxBQ3Jtc0tta0dKZFhrZXczWjZNeUVSUk5xSWxDOEFvbkU3YThobVBleWdaVFBMbTdycG5SdTZfd2VNT1RBX240aGZkZjg0UXh4elRDQkRlOTk5bVBwd0pTaVpFQUJ2WTRRVXV5S1FTQVlsQ1I3TXhNUUNPU1hkUQ&q=https%3A%2F%2Fhabr.com%2Fru%2Fcompanies%2Fdomclick%2Farticles%2F566224%2F) 
Контейнерная виртуализация в Linux [https://www.youtube.com/watch?v=rJRLZfk3a8U&t=1s&ab_channel=ComputerScienceCenter](https://www.youtube.com/watch?v=rJRLZfk3a8U&t=1s) 
Механизмы контейнеризации: namespaces [https://habr.com/ru/companies/selectel/articles/279281/](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqbXdqZGhmZ1Ixd0huQ3p5Q3VBZzlGWkN2S2NZZ3xBQ3Jtc0tuakUwdU1TQ014WHcxOU1Eck41SDI4QTRiU3lGM2tWajFUOHBBU0lCa0hya3FjMGNpb29LNlc5ZzRoN0liaXhva3J0RTY3YUxMbjk1NmxrNkFhaGYzYlhfT2JUZlE4dk5oR3RnMEs4TkNrMzZIMUprNA&q=https%3A%2F%2Fhabr.com%2Fru%2Fcompanies%2Fselectel%2Farticles%2F279281%2F) 
Механизмы контейнеризации: cgroups [https://habr.com/ru/companies/selectel/articles/303190/](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqa2Z5YkFOUXp0MGFMYlkyczJlcndHbUJIMmg0Z3xBQ3Jtc0tuNkpQbjBJVndNMWdXVmxUSGp3SUxhS3h6U0dDVWUtTWFXQ1BOVVpLTlQtbVRJYV9aVjY0TTB3bGJHbG9VQ2tpWThya2FZbFlCR1gxYTlONzU4WDZJSmJMc2JoUVlLMkQxYjlYdUlyMXBBaG9BRnFjSQ&q=https%3A%2F%2Fhabr.com%2Fru%2Fcompanies%2Fselectel%2Farticles%2F303190%2F)Кетов. Внутреннее устройство Linux. Глава 9 Capabilities [https://habr.com/ru/companies/otus/articles/471802/](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqazJDVWtzaWZ0M04yWWhncmFISy1saEtSMjJjd3xBQ3Jtc0ttYl9td3VoZTZWbFB3SDE1U1V0aDBTMlhjZ3ZXOTNHOXdVRk5mUUdTb3RmdVBkVmFtUjg4UlVmQzRzVGZQeUIyb09XZElYazhWSjdRTE9lOVpZbExRdUE1WTV0Z2I3eTNDejNxd0lEbEYzZTd2OVItbw&q=https%3A%2F%2Fhabr.com%2Fru%2Fcompanies%2Fotus%2Farticles%2F471802%2F) 
Тут пример с сетью Run your own container without Docker [https://medium.com/@alexander.murylev/run-your-own-container-without-docker-60c297faf010](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqa1Q4cFd2XzlrNVRiR2xibEozTXpGdGZ6cndoUXxBQ3Jtc0trREdmdjNhczlxdkx2NlFMZWY4UTduZFZtQlVDVVhXcmRZYjNHTlZocjFfd1RjMVd5SlVhWXNxZHBnUUR4a19QYnpTMWt1aGpnU1lNUW1BMHJKVHZmeXNOd3JPVmhtV1ZZMFZBVFJlTmNHeHF2ck9iaw&q=https%3A%2F%2Fmedium.com%2F%40alexander.murylev%2Frun-your-own-container-without-docker-60c297faf010) runc & OCI Deep Dive [https://mkdev.me/posts/the-tool-that-really-runs-your-containers-deep-dive-into-runc-and-oci-specifications](https://www.youtube.com/redirect?event=comments&redir_token=QUFFLUhqa25XQTA1TFFJeWdYQmZTOEdBbGZLZ3ZuQ3FmQXxBQ3Jtc0tsNGVtdUFPOXNOOWtSMWtOcFl3dGFhSEIyMC12bHlTMm5KaGtLU2daeVZtSHRNRUdoYmtwTFphb3ZmYzltWGNIay1XYXcwNXRSU3JneHIxYkJXT1ZLYVZKM3AxVGZ4ejc2TVkza0cwckxGMHRfcU1wSQ&q=https%3A%2F%2Fmkdev.me%2Fposts%2Fthe-tool-that-really-runs-your-containers-deep-dive-into-runc-and-oci-specifications)
