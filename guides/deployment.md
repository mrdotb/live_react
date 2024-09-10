# Deployment

[Without SSR](#without-ssr)
[With SSR](#with-ssr)

## Without SSR

The following steps are needed to deploy to Fly.io. This guide assumes that you'll be using Fly Postgres as your database. Further guidance on how to deploy to Fly.io can be found [here](https://fly.io/docs/elixir/getting-started/).

1. Generate a `Dockerfile`:

```bash
mix phx.gen.release --docker
```

2. Modify the generated `Dockerfile` to install `curl`, which is used to install `nodejs` (version 19 or greater), and also add a step to install our `npm` dependencies:

```diff
# ./Dockerfile

...

# install build dependencies
- RUN apt-get update -y && apt-get install -y build-essential git \
+ RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

+ # install nodejs for build stage
+ RUN curl -fsSL https://deb.nodesource.com/setup_19.x | bash - && apt-get install -y nodejs

...

COPY assets assets

+ # install all npm packages in assets directory
+ RUN cd /app/assets && npm install
```

Note: `nodejs` is installed in the build stage. This is because we need `nodejs` to install our `npm` dependencies.

3. Launch your app with the Fly.io CLI:

```bash
fly launch
```

4. When prompted to tweak settings, choose `y`:

```bash
? Do you want to tweak these settings before proceeding? (y/N) y
```

This will launch a new window where you can tweak your launch settings. In the database section, choose `Fly Postgres` and enter a name for your database. You may also want to change your database to the development configuration to avoid extra costs. You can leave the rest of the settings as-is unless you want to change them.

Deployment will continue once you hit confirm.

5. Once the deployment completes, run the following command to see your deployed app!

```bash
fly apps open
```

## With SSR

See the [SSR guide](/guides/ssr.md) first to setup your project.

The following steps are needed to deploy to Fly.io. This guide assumes that you'll be using Fly Postgres as your database. Further guidance on how to deploy to Fly.io can be found [here](https://fly.io/docs/elixir/getting-started/).

1. Generate a `Dockerfile`:

```bash
mix phx.gen.release --docker
```

2. Modify the generated `Dockerfile` to install `curl`, which is used to install `nodejs` (version 19 or greater), and also add a step to install our `npm` dependencies:

```diff
# ./Dockerfile

...

# install build dependencies
- RUN apt-get update -y && apt-get install -y build-essential git \
+ RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

+ # install nodejs for build stage
+ RUN curl -fsSL https://deb.nodesource.com/setup_19.x | bash - && apt-get install -y nodejs

...

COPY assets assets

+ # install all npm packages in assets directory
+ RUN cd /app/assets && npm install

...

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
-  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
+  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl \
   && apt-get clean && rm -f /var/lib/apt/lists/*_*

+ # install nodejs for production environment
+ RUN curl -fsSL https://deb.nodesource.com/setup_19.x | bash - && apt-get install -y nodejs

...
```

Note: `nodejs` is installed BOTH in the build stage and in the final image. This is because we need `nodejs` to install our `npm` dependencies and also need it when running our app.

3. Launch your app with the Fly.io CLI:

```bash
fly launch
```

4. When prompted to tweak settings, choose `y`:

```bash
? Do you want to tweak these settings before proceeding? (y/N) y
```

This will launch a new window where you can tweak your launch settings. In the database section, choose `Fly Postgres` and enter a name for your database. You may also want to change your database to the development configuration to avoid extra costs. You can leave the rest of the settings as-is unless you want to change them.

Deployment will continue once you hit confirm.

5. Once the deployment completes, run the following command to see your deployed app!

```bash
fly apps open
```
