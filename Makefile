service:=nuc

all: install enable start

install:
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
