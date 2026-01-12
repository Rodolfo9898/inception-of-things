.PHONY: up down destroy status ssh-s ssh-sw provision reload

VAGRANT ?= vagrant
PROVIDER ?= virtualbox

up:
	$(VAGRANT) up --provider=$(PROVIDER)

down:
	$(VAGRANT) halt

destroy:
	$(VAGRANT) destroy -f

status:
	$(VAGRANT) status

ssh-s:
	$(VAGRANT) ssh rperez-tS

ssh-sw:
	$(VAGRANT) ssh rperez-tSW

provision:
	$(VAGRANT) provision

reload:
	$(VAGRANT) reload
