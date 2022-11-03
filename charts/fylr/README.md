# fylr

## Good to know

### Secrets

- `<deployment-name>-fylr-oauth2`
- `<deployment-name>-fylr-utils`

These two secrets are used by the fylr installation to sign, encrypt, and configure the OAuth2 client and server. The values are generated during installation and are not updated during upgrades or deleted during uninstallation. If you want to change the values, you must adjust them manually.

### Persistent Volumes

Depending on your configuration, you can deploy fylr with a persistent volume. If you do this, these volumes are created once and are not deleted when you uninstall fylr. If you want to delete the volumes, you must do so manually.

## Configuration

The link below contains a table of the configurable parameters of the fylr diagram and their default values.

See: https://programmfabrik.github.io/fylr-helm/charts/fylr/
