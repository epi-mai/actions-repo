# Composite action to prepare automated tests.
_Composite action to prepare automated tests._


## Inputs
| Input | Description | Default | Required |
| --- | --- | --- | --- |
| docker_registry | Address of the registry that will contain the container. | ghcr.io | false |
| docker_registry_username | User name used to log in to the registry. | ${{ github.actor }} | false |
| docker_registry_password | Password used to log in to the registry. | undefined | false |
| docker_compose_filename | Filename of the compose file to be used from the directory "ci-tests" | docker-compose.yml | false |
