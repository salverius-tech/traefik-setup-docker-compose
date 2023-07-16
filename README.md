[![Discord notification Action](https://github.com/ilude/traefik-setup-docker-compose/actions/workflows/alert-traefik-project.yml/badge.svg)](https://github.com/ilude/traefik-setup-docker-compose/actions/workflows/alert-traefik-project.yml)
#### A docker-compose setup of common services with Traefik using cloudflare dns-01 for letsencrypt certificates

This repo assumes that you are running a debian linux disto like Ubuntu, so a few of the scripted commands below may need to be adjusted if you are running using a different distro or package management. You will need to install Docker and Docker-compose CLI on your linux host, you can do this by following the steps here:
[Docker Engine Linux Installation steps](https://docs.docker.com/engine/install/) and [Compose CLI](https://docs.docker.com/compose/install/linux/)


**Or** by using this bash script on Ubuntu available [here](https://github.com/traefikturkey/onvoy/tree/master/ubuntu/bash)

You'll need a personal domain that's setup with Cloudflare
and an API token created like so

![Cloudflare api token](https://cdn.discordapp.com/attachments/979867396800131104/985259853696102420/unknown.png "Cloudflare api token")

After installing Docker and getting your Cloudflare API key
you can run the following to do the basic setup automagically:

```
sudo apt install git make nano -y

sudo mkdir /apps
sudo chown -R $USER:$USER /apps
cd /apps
git clone https://github.com/traefikturkey/onramp.git onramp
cd onramp

```

Upon the initial run you shall be prompted to enter the following information:

    -Cloudflare Email Address
    -Cloudflare Access Token
    -Hostname of system OnRamp is running on.
    -Domain for which traefik will be handling requests
    -Timezone

Begin the setup process by entering:
```
make start-staging
```
After entering the start-staging command, follow the prompts and information that are presented.
```
make down-staging
```
You are now ready to bring things up with the production certificates

```
make
```

## Docker Services

Other docker services are included in the ./services-available directory
The configuration files include links to the web page for the services which has 
the available documentation. 

> Note : This also includes cautions and notices for some of the different services, so be sure to look at them.

To list them:
```
make list-services
```

They can be enabled by running the following commands:

```
make enable-service uptime-kuma
make restart
```
> Note: this creates a symlink file in ./services-enabled to the service.yml file in ./services-available

and disabled with the following:
```
make disable-service uptime-kuma
make restart
```

To create a new service:
```
make create-service name-of-service
```

This will create a file in /services-available that is built using the service.template



## Docker Overrides

Several docker overrides are included that allow extending the functionallity of existing services to add features like NFS mounted media directories and Intel Quicksync or Nvidia GPU support to the Plex and Jellyfin containers.

To list avaliable overrides:
```
make list-overrides
```

To enable an override:
```
make enable-override plex-nfs
make restart
```

To disable an override:
```
make disable-override plex-nfs
make restart
```
> Note: this creates a symlink file in ./overrides-enabled to the override.yml file in ./overrides-available
> In addition users can place there own custom docker compose files into ./overrides-enabled and they will be included on normal start up 
> as well as included in the backup file created when running make create-backup
> for more info on docker compose overrides see: https://docs.docker.com/compose/extends/#adding-and-overriding-configuration

## Docker Game servers

Docker based Game servers are included in the ./services-available/games directory.
The configuration files include links to the web page for the services which has 
the available documentation.

To list available games:
```
make list-games
```

To enable a game:
```
make enable-game factorio
make restart
```

To disable a game:
```
make disable-game factorio
make restart
```

## External Services
External services can also be proxied through Traefik to list the available configurations:

```
make list-external
```

They can be enabled by running the following commands:

```
make enable-external proxmox
make restart
```

And disabled with the following:
```
make disable-external proxmox
make restart
```
## Backing up Configuration

### Create backup file
```
make create-backup
```
This will create a traefik-config-backup.tar.gz in the project directory

### Copy backup file to another machine
```
scp ./backups/traefik-config-backup.tar.gz <user>@<other_host>:/apps/onramp/backups/
```

### Restore backup file on the other machine
```
make restore-backup
```

## Other make commands

Then you can run any of the following:

```
make          # does a docker compose up -d
make up       # does a docker compose up (this will show you the log output of the containers, but will not stay running if you hit ctrl-c or log out)
make down     # does a docker compose down
make restart  # does a docker compose down followed by an up -d
make logs     # does a docker compose logs -f
make update   # does a docker compose down, pull (to get the latest docker images) and up -d

# You can run multiple commands at once like this
make; make logs
```
## Environment Variables

Many parts of the available services, overrides and games can be customized using variables set in your .env file
If you open an available file and view it you will likely see many variables such as ${UNIFI_DOCKER_TAG:-latest-ubuntu}

UNIFI_DOCKER_TAG is the variable name 
latest-ubuntu is the default value

You can override this value by placing the following line in your .env file
```
UNIFI_DOCKER_TAG=latest-ubuntu-beta
```
This will enable pulling the latest-ubuntu-beta version of the unifi container instead of the default stable version

Please see https://docs.docker.com/compose/environment-variables/ for more information about environment variable in docker compose
