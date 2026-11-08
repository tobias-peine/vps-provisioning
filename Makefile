# Makefile - dieselben Pruefungen wie die CI, plus die zwei Deploy-Targets,
# die bewusst nur lokal laufen (siehe .github/workflows/ci.yml).
#
# Alle Targets sind idempotent und aendern nichts am Host - ausser dry-run
# und deploy, die nach Vault-Passwort und sudo-Passwort fragen.

SHELL := /bin/bash
PLAYBOOK := site.yml
INVENTORY := hosts.ini

.DEFAULT_GOAL := help

.PHONY: help setup lint yamllint ansible-lint syntax inventory check dry-run deploy audit clean

help: ## Targets und Zweck anzeigen
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## ansible-core, Linter und Collections installieren
	command -v ansible >/dev/null || pipx install ansible-core
	command -v ansible-lint >/dev/null || pipx install ansible-lint
	command -v yamllint >/dev/null || pipx install yamllint
	command -v shellcheck >/dev/null || echo "shellcheck fehlt - bitte 'apt install shellcheck'"
	ansible-galaxy collection install -r requirements.yml

yamllint: ## YAML-Stil pruefen (.yamllint)
	yamllint .

ansible-lint: $(INVENTORY) ## Ansible-Regeln pruefen (.ansible-lint)
	ansible-lint

syntax: $(INVENTORY) ## Playbook parsen, ohne Verbindung zum Host
	ansible-playbook $(PLAYBOOK) --syntax-check -i $(INVENTORY)

# hosts.ini ist gitignored; fuer Lint und Syntax-Check genuegt die Vorlage.
# Order-only (|): kopiert wird nur, wenn hosts.ini fehlt - nicht, wenn die
# Vorlage neuer ist. Sonst wuerde ein Edit an hosts.ini.example die echte
# Inventory-Datei mit Platzhaltern ueberschreiben.
$(INVENTORY): | hosts.ini.example
	cp hosts.ini.example $(INVENTORY)
	@echo "hosts.ini aus der Vorlage erzeugt - Tailscale-IP und Key-Pfad eintragen"

inventory: ## Hosts aus der Vorlage anzeigen
	ansible-inventory -i hosts.ini.example --graph

lint: yamllint ansible-lint ## Beide Linter (wie CI)

check: syntax lint ## Alles, was die CI auch macht

dry-run: $(INVENTORY) ## --check --diff gegen den echten Host
	ansible-playbook $(PLAYBOOK) --check --diff --ask-vault-pass -K

deploy: $(INVENTORY) ## Echter Lauf gegen den echten Host
	ansible-playbook $(PLAYBOOK) --diff --ask-vault-pass -K

audit: ## Secret-Muster in Arbeitskopie und Historie suchen
	./scripts/secret-audit.sh

clean: ## Retry-Files und Python-Caches entfernen
	rm -f ./*.retry
	find . -name '__pycache__' -type d -prune -exec rm -rf {} +
