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
	sudo journalctl -fu $(service)

logs:
	docker compose logs -f

hooks:
	cp -vf .githooks/* .git/hooks/
	git config --local receive.denyCurrentBranch updateInstead

sync:
	cat README.md
	docker compose up -d --force-recreate --remove-orphans

origin:
	git remote rm origin || true
	git remote add origin git@github.com:azoff/nuc.git
	git remote set-url --add origin azoff@nuc.azof.fr:nuc

deploy-key:
	[ -f ~/.ssh/id_ed25519.pub ] || ssh-keygen -t ed25519 -C "nuc" -f ~/.ssh/id_ed25519
	cat ~/.ssh/id_ed25519.pub
	ssh git@github.com
