.PHONY: fmt fmt-check validate security-check check

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

validate:
	terraform -chdir=bootstrap init -backend=false
	terraform -chdir=bootstrap validate
	terraform -chdir=environments/dev init -backend=false
	terraform -chdir=environments/dev validate

security-check:
	./scripts/check-no-persistent-secrets.sh

check: fmt-check validate security-check
