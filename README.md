## Getting Started

First time setting up, make sure you have a
mount at `SHARED_MOUNT_PATH` for storing media.

```sh
vim /etc/fstab
echo $SHARED_MOUNT_PATH
```

Install `docker` and `make`, let the `Makefile` do the rest:

```sh
sudo apt install make
make
```

