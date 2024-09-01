register:
	source .env && ./setup.sh --register public --dev

deregister:
	source .env && ./setup.sh --deregister --dev

validate:
	source .env && ./setup.sh --validate --dev

e2e:
	source .env && ./setup.sh --register --validate --dev
