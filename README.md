# Example Cloud Native App

![](./static/app.png)

This project illustrates how to create a simple 12-factor web app with
cloud-native continuous integration and deployment with a really simple web app.

The app is nothing special. It's just a web app that checks if a backend is up
upon clicking a button. It won't win any Webby awards any time soon!

## Running It Locally

### Prerequisites

- Docker and Docker Compose

### Instructions

1. Start the frontend and backend: `docker-compose up -d frontend backend`
2. Point your web browser to http://localhost:8080. Click the button. Witness
   the magic.

## Contributing to Cloud Native Example App

Thanks for helping out! Here is some information that you should know up front
about integration testing before diving in.

### Integration Test Infrastructure

This project spins up an AWS Elastic Kubernetes Services (EKS) cluster with a
single `t3g.medium` spot worker. As such, you'll need an AWS account in order to run
the integration tests.

[Go
here](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html)
to learn how to create an AWS account if you do not already have one.

**At this time of writing, this will cost ~$0.15/hr to operate.**

### Environment dotfiles (dotenvs)

This project uses [environment dotfiles, or `dotenv`s](https://dotenv.org) for
safely storing sensitive values. The dotenvs for the integration and production
environments are encrypted with GNU Privacy Guard, or GnuPG.

Creating your own dotenv is very easy. In a terminal:

1. Copy the `env.example` to `env.integration`. This file is never committed to
   Git.
2. Open `env.integration`. Change the variables that are set to `change-me`.
   Save.
3. `export` a password to encrypt `env.integration` with, like this:

   ```
   export ENV_PASSWORD=$YOUR_PASSWORD_HERE
   ```

   Use the command below to create a random `ENV_PASSWORD` quickly:

   ```
   export ENV_PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
   ```
4. Encrypt `env.integration`: `make encrypt_dotenv`.

## Testing

### Unit Tests

#### Prerequisites

- Docker and Docker Compose

#### Instructions

`make unit-tests`.

### Integration Testing

#### Prerequisites

- AWS Account (see note above)
- An encrypted integration `dotenv` (see note above)
- Docker and Docker Compose

#### Instructions

1. Build the OCI images for the backend and frontend: `make build`
2. Push the images to the image repository defined in your `dotenv`: `make
   push-images`
3. Setup the environment: `make integration-setup`
4. Deploy the images: `make integration-deploy`
5. Run the tests: `make integration-test`
