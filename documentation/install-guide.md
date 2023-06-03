# Installation Guide for OnRamp

## 1. Preparation

<p>
    This repository makes the assumption that you're running a debian based distro of linux like ubuntu, so a few of the scripted commands below may need to be adjusted if you are using a different distro or package management. You will need to install docker on your linux host and obtain a cloudflare API token.
</p>

- Install Docker

    Below are two different methods for installing docker:
    * [Docker Linux Installation steps](https://docs.docker.com/desktop/linux/install/#generic-installation-steps)
    * or using this bash script on ubuntu available [here](https://github.com/traefikturkey/onvoy/tree/master/ubuntu/bash)

   

- Get Cloudflare API Token

<p>You'll need a personal domain that's setup with Cloudflare
and an API token created like so</p>

![Cloudflare api token](assets/cloudflare-api.png)

## 2. Installation

    After installing docker and obtaining a Cloudflare API token
    you can run the following to do the basic setup automagically:

    ```
    sudo apt install git make nano -y

    sudo mkdir /apps
    sudo chown -R $USER:$USER /apps
    cd /apps
    git clone https://github.com/traefikturkey/onramp.git onramp
    cd onramp
    ```

## 3. Configuration and Startup

    Upon the initial run you shall be prompted to enter the following information:

        -Cloudflare Email Address
        -Cloudflare Access Token
        -Hostname of system OnRamp is running on.
        -Domain for which traefik will be handling requests
        -Timezone

    Staging

    Begin the configuration and startup process by entering the following command:

    ```
    make start-staging
    ```

    traefik will start and attempt to obtain a staging certificate wait and then follow the on screen directions


    ```
    make down-staging
    ```
    you are now ready to bring things up with the production certificates

    ```
    make
    ```

## 3. Usage

### Services