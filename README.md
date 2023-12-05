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

**At this time of writing, this will cost ~$0.15/hr to operate.**

[Go
here](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html)
to learn how to create an AWS account if you do not already have one.

### Configuring IAM

Once you've created your AWS account, you will need to create a user that can
assume the `AWSAdministrator` role within AWS Identity Access Management (IAM)
via the AWS Security Token Service (STS). STS prevents you from having to
create an overly-privileged superuser within IAM by issuing temporary tokens
that expire within a short duration (less than 12 hours).

Download and install the AWS CLI if you have not already done so.

Once done, [visit this
page](https://repost.aws/knowledge-center/iam-assume-role-cli) to learn how to
do this, then in your `env.integration` and `env.production` dotenvs, populate
the following:

```sh
AWS_ACCESS_KEY_ID=$IAM_USER_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$IAM_USER_SECRET_ACCESS_KEY
AWS_ROLE_ARN=$NAME_OF_ROLE_THAT_YOU_CREATED
# see the note below to learn how to generate this
AWS_EXTERNAL_ID=$EXTERNAL_ID_FOR_THE_ROLE_THAT_YOU_CREATED
```

> ✅ **NOTE**: External IDs are kind-of like passwords for accounts trying to
> assume roles. They prevent unknown users from trying to assume roles. Add the
> JSON to your trust policy JSON document to add an "external ID" to the IAM
> role's trust policy JSON document:
>
> ```json
> "Condition": {"StringEquals": {"sts:ExternalId": "$RANDOM_PASSWORD"}}
> ```


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

### Infrastructure Testing

Our example app also provides an example of how to perform infrastructure
testing locally. This stack uses [Localstack](https://localstack.cloud) and
[Terratest](https://terratest.gruntwork.io) to validate our infrastructure
in a mock environment.

> ⚠️  You will need a LocalStack Pro subscription in order to run these tests.
> You can sign up for a 14-day free trial [here](https://app.localstack.cloud).
> Once you sign up, copy your `LOCALSTACK_AUTH_TOKEN`, paste it into
> `.env.integration` and, optionally, re-encrypt it with
> `make encrypt_integration_dotenv`.

#### Prerequisites

- Docker and Docker Compose
- LocalStack Pro (see above)

#### Instructions

`make infra-tests`

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
