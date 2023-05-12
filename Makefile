service:=nuc

all: permissions mount install build daemon enable start

permissions:
	sudo usermod -aG docker $(USER) # requires logout/login

mount:
	sudo mount -av

install:
	sudo apt update
	sudo apt remove -y docker docker.io containerd runc
	sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo \
	  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
	  $(shell lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt update
	sudo apt install -y docker-ce docker-ce-cli containerd.io

build:
	docker compose build

daemon:
	sudo cp -fv system/nuc.service /etc/systemd/system/$(service).service

enable:
	sudo systemctl enable $(service)

start:
	sudo systemctl start $(service)

status:
	sudo systemctl status $(service)

journal:
	sudo journalctl -u $(service)

logs:
	docker compose logs -f
