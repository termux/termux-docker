#!/usr/bin/env bash

docker build -t 'xeffyr/termux:latest' -f i686/Dockerfile .
docker build -t 'xeffyr/termux:x86_64' -f x86_64/Dockerfile .

if [ "$(whoami)" = "xeffyr" ]; then
	docker push 'xeffyr/termux:latest'
	docker push 'xeffyr/termux:x86_64'
fi
