# coolify-auto-setup

This repo contains a script that allows you to auto register your machines
against your coolify instance

Example Usage:

*Note: In order to use this script your coolify domain must be exposed as `$URL` 
and api token as `$API_TOKEN` for the script to access*

Fully setup machine ready for use:
```bash
./setup.sh --register <local|public>  --validate
```

Just register your machine:
```bash
./setup.sh --register <local|public>
```

Deregister your machine:
```bash
./setup.sh --deregister
```
