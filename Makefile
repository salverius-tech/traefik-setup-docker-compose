# include .env variable in the current environment
ENVIRONMENT_FILES := $(wildcard ./environments-enabled/*.env)
ifneq (,$(wildcard ./environments-enabled/*.env))
    include ${ENVIRONMENT_FILES}
    export
endif

# look for the second target word passed to make
export SERVICE_PASSED_DNCASED := $(strip $(word 2,$(MAKECMDGOALS)))
export SERVICE_PASSED_UPCASED := $(strip $(subst -,_,$(shell echo $(SERVICE_PASSED_DNCASED) | tr a-z A-Z )))

export DOCKER_COMPOSE_FILES :=  $(wildcard services-enabled/*.yml) $(wildcard overrides-enabled/*.yml) $(wildcard docker-compose.*.yml) 
export DOCKER_COMPOSE_FLAGS := -f docker-compose.yml $(foreach file, $(DOCKER_COMPOSE_FILES), -f $(file))

DOCKER_COMPOSE_DEVELOPMENT_FILES := $(wildcard services-dev/*.yml)
DOCKER_COMPOSE_DEVELOPMENT_FLAGS := --project-directory ./ $(foreach file, $(DOCKER_COMPOSE_DEVELOPMENT_FILES), -f $(file))

# used to look for the file in the services-enabled folder when [start|stop|pull]-service is used 
SERVICE_FILES := $(wildcard services-enabled/$(SERVICE_PASSED_DNCASED).yml) $(wildcard overrides-enabled/$(SERVICE_PASSED_DNCASED)-*.yml)
SERVICE_FLAGS := --project-directory ./ $(foreach file, $(SERVICE_FILES), -f $(file))

# get the boxes ip address and the current users id and group id
export HOSTIP := $(shell ip route get 1.1.1.1 | grep -oP 'src \K\S+')
export PUID 	:= $(shell id -u)
export PGID 	:= $(shell id -g)
export HOST_NAME := $(or $(HOST_NAME), $(shell hostname))
export CF_RESOLVER_WAITTIME := $(strip $(or $(CF_RESOLVER_WAITTIME), 30))

# check if we should use docker-compose or docker compose
ifeq (, $(shell which docker-compose))
	DOCKER_COMPOSE := docker compose
else
	DOCKER_COMPOSE := docker-compose
endif

# setup PLEX_ALLOWED_NETWORKS defaults if they are not already in the .env file
ifndef PLEX_ALLOWED_NETWORKS
	export PLEX_ALLOWED_NETWORKS := $(HOSTIP/24)
endif

# check what editor is available
ifdef VSCODE_IPC_HOOK_CLI
	EDITOR := code
else
	EDITOR := nano
endif

# use the rest as arguments as empty targets aka: MAGIC
EMPTY_TARGETS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(EMPTY_TARGETS):;@:)

# this is the default target run if no other targets are passed to make
# i.e. if you just type: make
start: build
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) up -d --remove-orphans
	
remove-orphans: build
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) up -d --remove-orphans	

up: build
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) up --force-recreate --remove-orphans --abort-on-container-exit

down: 
	-$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) down --remove-orphans
	-docker volume ls --quiet --filter "label=remove_volume_on=down" | xargs -r docker volume rm 

pull:
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) pull

logs:
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) logs -f $(SERVICE_PASSED_DNCASED)

restart: down start

update: down pull start

bash-run:
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) run -it --rm $(SERVICE_PASSED_DNCASED) sh

bash-exec:
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) exec $(SERVICE_PASSED_DNCASED) sh

#########################################################
#
# install commands
#
#########################################################

install-ansible:
	sudo apt-add-repository ppa:ansible/ansible -y
	sudo apt update
	sudo apt install ansible -y
	@echo "Beginning installing ansible roles requirements..."
	ansible-playbook ansible/ansible-requirements.yml
	@echo "Completed installing ansible roles requirements..."

install-docker: install-ansible
	ansible-playbook ansible/install-docker.yml

install-node-exporter: install-ansible
	ansible-playbook ansible/install-node-exporter.yml

install-nvidia-drivers: install-ansible
	ansible-playbook ansible/install-nvidia-drivers.yml

#########################################################
#
# service commands
#
#########################################################

start-service: COMPOSE_IGNORE_ORPHANS = true 
start-service: enable-service build 
	$(DOCKER_COMPOSE) $(SERVICE_FLAGS) up -d --force-recreate $(SERVICE_PASSED_DNCASED)

down-service: stop-service
stop-service: 
	-$(DOCKER_COMPOSE) $(SERVICE_FLAGS) stop $(SERVICE_PASSED_DNCASED)

restart-service: down-service start-service

update-service: down-service pull-service start-service
pull-service: 
	$(DOCKER_COMPOSE) $(SERVICE_FLAGS) pull $(SERVICE_PASSED_DNCASED)
 
enable-game: etc/$(SERVICE_PASSED_DNCASED)
ifneq (,$(wildcard ./services-available/games/$(SERVICE_PASSED_DNCASED).yml))
	@echo "Enabling $(SERVICE_PASSED_DNCASED)..."
	@ln -s ../services-available/games/$(SERVICE_PASSED_DNCASED).yml ./services-enabled/$(SERVICE_PASSED_DNCASED).yml || true
else
	@echo "No such game file ./services-available/games/$(SERVICE_PASSED_DNCASED).yml!"
endif
	
.PHONY: enable-service build 
enable-service: etc/$(SERVICE_PASSED_DNCASED) services-enabled/$(SERVICE_PASSED_DNCASED).yml environments-enabled/$(SERVICE_PASSED_DNCASED).env

etc/$(SERVICE_PASSED_DNCASED):
	@mkdir -p ./etc/$(SERVICE_PASSED_DNCASED)

services-enabled/$(SERVICE_PASSED_DNCASED).yml:
ifneq (,$(wildcard ./services-available/$(SERVICE_PASSED_DNCASED).yml))
	@echo "Enabling $(SERVICE_PASSED_DNCASED)..."
	@ln -s ../services-available/$(SERVICE_PASSED_DNCASED).yml ./services-enabled/$(SERVICE_PASSED_DNCASED).yml || true
else
	@echo "No such service file ./services-available/$(SERVICE_PASSED_DNCASED).yml!"
endif

environments-enabled/$(SERVICE_PASSED_DNCASED).env:
	@python3 scripts/env-subst.py environments-available/$(SERVICE_PASSED_DNCASED).template $(SERVICE_PASSED_UPCASED)

remove-game: disable-service
disable-game: disable-service
remove-service: disable-service
disable-service: stop-service
	rm ./services-enabled/$(SERVICE_PASSED_DNCASED).yml
	rm ./overrides-enabled/$(SERVICE_PASSED_DNCASED)-*.yml 2> /dev/null || true

create-service:
	envsubst '$${SERVICE_PASSED_DNCASED},$${SERVICE_PASSED_UPCASED}' < ./.templates/service.template > ./services-available/$(SERVICE_PASSED_DNCASED).yml
	$(EDITOR) ./services-available/$(SERVICE_PASSED_DNCASED).yml

create-game:
	envsubst '$${SERVICE_PASSED_DNCASED},$${SERVICE_PASSED_UPCASED}' < ./.templates/service.template > ./services-available/games/$(SERVICE_PASSED_DNCASED).yml
	$(EDITOR) ./services-available/games/$(SERVICE_PASSED_DNCASED).yml

start-dev: COMPOSE_IGNORE_ORPHANS = true 
start-dev: build services-dev
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_DEVELOPMENT_FLAGS) up -d --force-recreate $(SERVICE_PASSED_DNCASED)

stop-dev:
	-$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_DEVELOPMENT_FLAGS) stop $(SERVICE_PASSED_DNCASED)

services-dev:
	mkdir -p ./services-dev

#########################################################
#
# compose commands
#
#########################################################

start-compose: COMPOSE_IGNORE_ORPHANS = true 
start-compose: build 
	$(DOCKER_COMPOSE) $(SERVICE_FLAGS) up -d --force-recreate

down-compose: stop-compose
stop-compose: 
	-$(DOCKER_COMPOSE) $(SERVICE_FLAGS) stop

update-compose: down-compose pull-compose start-compose
pull-compose: 
	$(DOCKER_COMPOSE) $(SERVICE_FLAGS) pull

compose-run:
	$(DOCKER_COMPOSE) $(SERVICE_FLAGS) run $(SERVICE_PASSED_DNCASED) $(second_arg)
	
#########################################################
#
# staging commands
#
#########################################################

start-staging: build
	ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory $(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) up -d --force-recreate
	@echo "waiting $(CF_RESOLVER_WAITTIME) seconds for cert DNS propogation..."
	@sleep $(CF_RESOLVER_WAITTIME)
	@echo "open https://$(HOST_NAME).$(HOST_DOMAIN)/traefik in a browser"
	@echo "and check that you have a staging cert from LetsEncrypt!"
	@echo ""
	@echo "if you don't get a LetsEncrypt staging cert run the following command and look for error messages:"
	@echo "$(DOCKER_COMPOSE) logs | grep acme"
	@echo ""
	@echo "otherwise run the following command if you successfully got a staging certificate:"
	@echo "make down-staging"

down-staging:
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) down
	$(MAKE) clean-acme

#########################################################
#
# list commands
#
#########################################################

list-games:
	@ls -1 ./services-available/games | sed -n 's/\.yml$ //p'

list-services:
	@ls -1 ./services-available/ | sed -e 's/\.yml$ //'

list-overrides:
	@ls -1 ./overrides-available/ | sed -e 's/\.yml$ //'

list-external:
	@ls -1 ./etc/traefik/available/ | sed -e 's/\.yml$ //'

list-enabled:
	@printf "%s\n" $(shell ls -1 ./services-enabled/ | sed -e 's/\.yml$ //' )

print-enabled:
	@printf "%s\n" "Here are your enabled services : " $(shell ls -1 ./services-enabled/ | sed -e 's/\.yml$ //' )

count-enabled:
	@echo "Total services run in onramp (this is excluding Traefik, and multi-services composes are counted as one) : " $(shell make list-enabled | wc -l )

list-count: print-enabled count-enabled


#########################################################
#
# build related commands
#
#########################################################

build: environments-enabled/onramp.env etc/authelia/configuration.yml etc/dashy/dashy-config.yml etc/prometheus/conf etc/adguard/conf/AdGuardHome.yaml

environments-enabled/onramp.env:
	@clear
	@echo "***********************************************"
	@echo "Traefik Turkey OnRamp Setup"
	@echo "***********************************************"
	@echo ""
	@echo "Welcome to OnRamp - Traefik with all the stuffing."
	@echo ""
	@echo ""
	@echo "To proceed with the initial setup you will need to "
	@echo "provide some information that is required for"
	@echo "OnRamp to function properly."
	@echo ""
	@echo "Required information:"
	@echo ""
	@echo "--> Cloudflare Email Address"
	@echo "--> Cloudflare Access Token"
	@echo "--> Hostname of system OnRamp is running on."
	@echo "--> Domain for which traefik will be handling requests"
	@echo "--> Timezone"
	@echo ""
	@echo ""
	@echo ""
	@python3 scripts/env-subst.py environments-available/onramp.template "ONRAMP"

etc/authelia/configuration.yml:
	envsubst '$${HOST_DOMAIN}' < ./etc/authelia/configuration.template > ./etc/authelia/configuration.yml

etc/adguard/conf/AdGuardHome.yaml:
	envsubst '$${ADGUARD_PASSWORD}, $${ADGUARD_USER}, $${HOST_DOMAIN}' < ./etc/adguard/conf/AdGuardHome.template > ./etc/adguard/conf/AdGuardHome.yaml

etc/pihole/dnsmasq/03-custom-dns-names.conf:
	envsubst '$${HOST_DOMAIN}, $${HOSTIP} ' < ./etc/pihole/dns.template > ./etc/pihole/dnsmasq/03-custom-dns-names.conf

etc/dashy/dashy-config.yml:
	mkdir -p ./etc/dashy
	touch ./etc/dashy/dashy-config.yml

etc/prometheus/conf:
	mkdir -p etc/prometheus/conf
	cp --no-clobber --recursive	etc/prometheus/conf-originals/* etc/prometheus/conf

#########################################################
#
# override commands
#
#########################################################

enable-override: overrides-enabled/$(SERVICE_PASSED_DNCASED).yml
overrides-enabled/$(SERVICE_PASSED_DNCASED).yml:
	@ln -s ../overrides-available/$(SERVICE_PASSED_DNCASED).yml ./overrides-enabled/$(SERVICE_PASSED_DNCASED).yml || true

remove-override: disable-override
disable-override:
	rm ./overrides-enabled/$(SERVICE_PASSED_DNCASED).yml 

#########################################################
#
# external commands
#
#########################################################

disable-external:
	rm ./etc/traefik/enabled/$(SERVICE_PASSED_DNCASED).yml

enable-external:
	@cp ./etc/traefik/available/$(SERVICE_PASSED_DNCASED).yml ./etc/traefik/enabled/$(SERVICE_PASSED_DNCASED).yml || true

create-external:
	envsubst '$${SERVICE_PASSED_DNCASED},$${SERVICE_PASSED_UPCASED}' < ./.templates/external.template > ./etc/traefik/available/$(SERVICE_PASSED_DNCASED).yml
	$(EDITOR) ./etc/traefik/available/$(SERVICE_PASSED_DNCASED).yml

#########################################################
#
# helper commands
#
#########################################################

edit-env:
	$(EDITOR) .env

#########################################################
#
# backup and restore up commands
#
#########################################################

export-backup: create-backup
	@echo "export-backup is depercated and will be removed in the future, please use make create-backup"

import-backup: restore-backup
	@echo "import-backup is depercated and will be removed in the future, please use make restore-backup"

create-backup: backups
	sudo tar --exclude=.keep -czf ./backups/onramp-config-backup-$(HOST_NAME)-$(shell date +'%y-%m-%d-%H%M').tar.gz ./etc ./services-enabled ./overrides-enabled .env || true

create-nfs-backup: create-backup
	sudo mount -t nfs $(NFS_SERVER):$(NFS_BACKUP_PATH) $(NFS_BACKUP_TMP_DIR)
	sudo mv ./backups/onramp-config-backup* $(NFS_BACKUP_TMP_DIR)
	sudo umount $(NFS_BACKUP_TMP_DIR)

backups:
	mkdir -p ./backups/

restore-backup:
	sudo tar -xvf ./backups/onramp-config-backup-$(HOST_NAME)-*.tar.gz

$(NFS_BACKUP_TMP_DIR):
	sudo mkdir -p $(NFS_BACKUP_TMP_DIR)
	sudo mount -t nfs $(NFS_SERVER):$(NFS_BACKUP_PATH) $(NFS_BACKUP_TMP_DIR)
	
restore-nfs-backup: $(NFS_BACKUP_TMP_DIR) backups
	$(eval BACKUP_FILE := $(shell find $(NFS_BACKUP_TMP_DIR)/*$(HOST_NAME)* -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f 2- | tail -n 1))
	sudo rm -rf ./backups/*
	cp -p  $(BACKUP_FILE) ./backups/
	sudo tar -xvf ./backups/*
	echo $(shell basename $(BACKUP_FILE)) > .restore_latest
	sudo umount $(NFS_BACKUP_TMP_DIR)
	sudo rm -r $(NFS_BACKUP_TMP_DIR)
	echo -n "Please run 'make restart' to apply restored backup"	

#########################################################
#
# clean up commands
#
#########################################################

clean-acme:
	@echo "removing acme certificate file"
	sudo rm etc/traefik/letsencrypt/acme.json

prune:
	docker image prune

prune-force:
	docker image prune -f

prune-update: prune-force update

remove-etc: 
	rm -rf ./etc/$(or $(SERVICE_PASSED_DNCASED),no_service_passed)/

reset-database-folder:
	rm -rf ./media/databases/$(or $(SERVICE_PASSED_DNCASED),no_service_passed)/
	git checkout ./media/databases/$(or $(SERVICE_PASSED_DNCASED),no_service_passed)/.keep

reset-etc: remove-etc
	git checkout ./etc/$(or $(SERVICE_PASSED_DNCASED),no_service_passed)/

stop-reset-etc: stop-service reset-etc

reset-database: remove-etc reset-database-folder	

#########################################################
#
# cloudflare tunnel commands
#
#########################################################

CLOUDFLARE_CMD = $(DOCKER_COMPOSE) $(DOCKER_COMPOSE_FLAGS) run --rm cloudflare-tunnel

./etc/cloudflare-tunnel/cert.pem:
	$(CLOUDFLARE_CMD) login

create-tunnel: ./etc/cloudflare-tunnel/cert.pem
	$(CLOUDFLARE_CMD) tunnel create $(CLOUDFLARE_TUNNEL_NAME)
	$(CLOUDFLARE_CMD) tunnel route dns $(CLOUDFLARE_TUNNEL_NAME) $(CLOUDFLARE_TUNNEL_HOSTNAME)

delete-tunnel:
	$(CLOUDFLARE_CMD) tunnel cleanup $(CLOUDFLARE_TUNNEL_NAME)
	$(CLOUDFLARE_CMD) tunnel delete $(CLOUDFLARE_TUNNEL_NAME)

show-tunnel:
	$(CLOUDFLARE_CMD) tunnel info $(CLOUDFLARE_TUNNEL_NAME)

#########################################################
#
# mariadb commands
#
#########################################################

ifndef MARIADB_CONTAINER_NAME
MARIADB_CONTAINER_NAME=mariadb
endif

# enable this to be asked for password to when you connect to the database
#mysql-connect = @docker exec -it $(MARIADB_CONTAINER_NAME) mysql -p

# enable this to not be asked for password to when you connect to the database
mysql-connect = @docker exec -it $(MARIADB_CONTAINER_NAME) mysql -p$(MARIADB_ROOT_PASSWORD)

first_arg = $(shell echo $(EMPTY_TARGETS)| cut -d ' ' -f 1)
second_arg = $(shell echo $(EMPTY_TARGETS)| cut -d ' ' -f 2)

password := $(shell openssl rand -hex 16)


mariadb-console:
	$(mysql-connect)

create-database:
	$(mysql-connect) -e 'CREATE DATABASE IF NOT EXISTS $(first_arg);'

show-databases: 
	$(mysql-connect) -e 'show databases;'

create-db-user:
	$(mysql-connect) -e 'CREATE USER $(first_arg) IDENTIFIED BY "'$(second_arg)'";'

create-db-user-pw: 
	@echo Here is your password : $(password) : Please put it in the .env file under the service name
	$(mysql-connect) -e 'CREATE USER IF NOT EXISTS $(first_arg) IDENTIFIED BY "'$(password)'";'

grant-db-perms:
	$(mysql-connect) -e 'GRANT ALL PRIVILEGES ON '$(first_arg)'.* TO $(first_arg);'

remove-db-user: 
	$(mysql-connect) -e 'DROP USER $(first_arg);'

drop-database:
	$(mysql-connect) -e 'DROP DATABASE $(first_arg);'

create-user-with-db: create-db-user-pw create-database grant-db-perms

#########################################################
#
# prestashop commands
#
#########################################################

remove-presta-install-folder:
	@sudo rm -rf etc/prestashop/install/

rename-presta-admin:
	@sudo mv etc/prestashop/admin/ etc/prestashop/$(first_arg)

#########################################################
#
# test and debugging commands
#
#########################################################

excuse:
	@curl -s programmingexcuses.com | egrep -o "<a[^<>]+>[^<>]+</a>" | egrep -o "[^<>]+" | sed -n 2p

test-smtp:
	envsubst .templates/smtp.template | nc localhost 25

# https://stackoverflow.com/questions/7117978/gnu-make-list-the-values-of-all-variables-or-macros-in-a-particular-run
echo:
	@$(MAKE) -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | grep -e "^[A-Z]+*" | sort

env:
	@env | sort

include env_ifs.mk
