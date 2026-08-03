.PHONY: fmt fmt-check validate check

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

validate:
	terraform -chdir=bootstrap init -backend=false
	terraform -chdir=bootstrap validate
	terraform -chdir=environments/dev init -backend=false
	terraform -chdir=environments/dev validate
	terraform -chdir=environments/stage init -backend=false
	terraform -chdir=environments/stage validate

check: fmt-check validate
