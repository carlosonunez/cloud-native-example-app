# Build, Test, Deploy

This `README` describes the design goals and architecture of the GitHub Actions [CI/CD
pipeline](.github/workflows/main.yaml) accompanying this project.

## Architecture

The pipeline is broken up into three stages: Unit Tests, Build, Integration Tests and
Production Deployment.

### Unit Tests

Sets up Docker Compose and runs unit tests against the frontend and backend,
just like you would locally. Nothing special.

### Build

> **Requires**: Unit Tests

Build OCI images for the frontend and backend, then pushes them to the image
registry defined in the project's dotenv.

### Integration Tests

Stands up a real-deal EKS cluster in an AWS VPC, deploys the app into it as a
Helm chart, runs integration tests provided by the app against the live
instance, then tears down the environment to save money and prevent false
positives (by using an environment that was modified to make tests pass).

### Production Deployent

Stands up (or updates) a real-deal EKS cluster in a separate AWS VPC and deploys
the app into it with Helm.

## Design Goals

- **Modularity**. The pipeline is designed to support additional steps that
  aren't currently accounted for. This is important, as software releases in
  enterprise settings typically include additional steps that are not accounted
  for by this example, like security scanning, performance testing and end user
  acceptance.

- **Zero Special Steps**. Every step in the pipeline is a `make` target in the
  application's `Makefile`. This enables dev teams to have enough autonomy to
  define how their app should be built and tested while providing platform teams
  the ablity to insert guardrails provided by their own pipelines.

- **Repeatability**. Starting new projects from scratch or migrating
  non-cloud-native projects into a cloud-native world is one of the biggest
  challenges enterprise dev teams face today. As such, this codebase is
  structured in a way that can serve as a template for future projects.

  In other words, a Platform engineer could take this repo, remove the contents
  within the `app` directory, delete the `GPG`-encrypted dotenvs and present
  this as a "New Project Template" for any dev team looking to modernize.

  Platform teams with polygot software developers can also customize the
  template to publish examples for popular tech stacks the company uses. In true
  DevOps fashion, they can also accept pull requests from other teams who want
  to contribute to their list of "New Project" templates
