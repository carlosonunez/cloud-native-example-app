## Things Missing

Unfortunately, this isn't a _complete_ example of a production-grade
cloud-native application.

This README tracks items that are missing that will, one-day, be added to this
repository.

- **HTTPS**. The app deploys without HTTPS. Obviously this won't cut it in a
  real-world setting. Use Cert Manager and Let's Encrypt to demonstrate how
  easily HTTPS can be added into Kubernetes-backed applications. _This will
  require you to have a DNS zone or the ability to modify /etc/hosts._
