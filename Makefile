service:=nuc
volume:=/dev/sda1

all: mount install enable start

mount:
	sudo mkdir /media/plex
	sudo mount -t ext4 $(volume) /media/plex

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
