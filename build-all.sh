#!/usr/bin/env bash

sudo docker build -t 'xeffyr/termux:latest' -f Dockerfile.32bit .
sudo docker build -t 'xeffyr/termux:x86_64' -f Dockerfile.64bit .

if [ "${1-}" = "publish" ]; then
	sudo docker push 'xeffyr/termux:latest'
	sudo docker push 'xeffyr/termux:x86_64'
fi
