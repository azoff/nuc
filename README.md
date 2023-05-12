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

## Deployment

Make a deployment key and add it to github. The following command will only make one, and will check if the key is added after every run.

```sh
make deploy-key
```

Checkout the `production` branch with the deployment key, and then you can add your deployment host as a remote (see `make origin`).

If you'd like to trigger deployments when the server receives refs, you'll need to install the post-update hook on the server:

```sh
make hooks
```

Then, the next time you `git push` some refs to the server, it will run `make sync` on the server.