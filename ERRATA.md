## Things Missing

Unfortunately, this isn't a _complete_ example of a production-grade
cloud-native application.

This README tracks items that are missing that will, one-day, be added to this
repository.

- **HTTPS**. The app deploys without HTTPS. Obviously this won't cut it in a
  real-world setting. Use Cert Manager and Let's Encrypt to demonstrate how
  easily HTTPS can be added into Kubernetes-backed applications. _This will
  require you to have a DNS zone or the ability to modify /etc/hosts._
- **Healthiness Probes**: This app is missing healthchecks. These are easy
  enough to add, but I didn't want to wait the 15+ minutes for a cluster to get
  spun up, so I left them out.
- **Infrastructure integration testing**. See [Infra integration
  testing](#infra-integration-testing) for more.

## Infra Integration Testing

This codebase includes an example of validation-based infrastructure testing.
This approach tests that the infrastructure code will generate the
infrastructure we expect before applying any configuration.

A more complete example would follow up on this by adding integration tests to
ensure that the infrastructure created matches our expectations. There are
several tools that help with this, like Goss and Testinfra.
