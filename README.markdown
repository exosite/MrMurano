# Murano Command Line Interface (CLI)

Do more from the command line with [Murano](https://exosite.com/platform/).

MuranoCLI interacts with Murano and makes different tasks easier.

MuranoCLI makes it easy to deploy code to a project, import
product definitions, set up endpoints and APIs, and more.

MuranoCLI works around the idea of syncing, much like [`rsync`](https://rsync.samba.org/).
Your project files are synced up (or down) from Murano.

## Contents

* [Contents](#contents)
* [Usage](#usage)
   * [Start a new project easily with init](#start-a-new-project-easily-with-init)
   * [Start a new project manually, step-by-step](#start-a-new-project-manually-step-by-step)
* [Install](#install)
   * [Gem Install (Linux and macOS)](#gem-install-linux-and-macos)
      * [Working With Different Versions of MuranoCLI](#working-with-different-versions-of-muranocli)
   * [Windows Install](#windows-install)
* [Features](#features)
   * [Logs](#logs)
   * [CORS](#cors)
   * [Writing Routes (a.k.a. Endpoints)](#writing-routes-aka-endpoints)
   * [Writing Service Event Handlers](#writing-service-event-handlers)
   * [MURANO_CONFIGFILE Environment Variable and Dotenv](#murano_configfile-environment-variable-and-dotenv)
   * [Direct Service Access](#direct-service-access)
   * [Output Format](#output-format)
   * [Product Content Area](#product-content-area)
* [Developing](#developing)
   * [Testing](#testing)

## Usage

### Start a new project easily with `init`

```
mkdir myproject
cd myproject
murano init
```

If you want to add information about your project, edit `myproject.murano`.
You can add a description, the list of authors, a version number, and more.

If you are connecting to an existing project
created with the [web interface](https://www.exosite.io/business/),
you may need to run `murano link set` to connect the product and the application.
But if you create a new product and application using MuranoCLI, they will
automatically be connected.

If you are connecting to an existing project, you may want to run
`murano syncdown` to pull down your project files from Murano.

Now do stuff, like add and edit files.

To see what files have changed, run `murano status`.

To see exactly what changed, try `murano diff`.

When you are ready to deploy, run `murano syncup`.

### Start a new project manually, step-by-step

If you would like to setup a project without using `murano init`,
follow these steps.

- Find your business ID. Run the command

  `murano business list`

  and copy its ID from the list.

  - If this is the first time you've run `murano`, you will
    need to enter your Murano username and password.

    (To sign up for a free account, visit [exosite.com](https://exosite.com/signup/).)

  - If you need to change change accounts, try

    `murano logout`

    `murano login`.

    - To manually change you username and password, run

      `murano config user.name <USERNAME>`

      `murano password set <USERNAME>`.

- Add the copied Business ID to your project config.

  `murano config business.id <BUSINESS-ID>`

- Create a new Application and save its ID to the project config.

  `murano application create myawesomeapplication --save`

  - Alternatively, choose an existing Application.

    `murano config application.id <APPLICATION-ID>`

- Create a new Product and save its ID to the project config.

  `murano product create myawesomeproduct --save`

  - Alternatively, choose an existing Product.

    `murano config product.id <PRODUCT-ID>`

- Link the Product to the Application.

  `murano link set`

- Build your project.

  - Edit and create event handlers under `services/`.

  - Create API endpoints under `routes/`.

  - Add Lua modules under `modules/`.

  - Add static files under `files/`.

  - Add resource aliases to the file, `specs/resources.yaml`.

- See what changed.

  `murano status`

  or

  `murano diff`

- Deploy your project. Sync up resources, code and files.

  `murano syncup`

## Install

### Gem Install (Linux and macOS)

The easiest way to install MuranoCLI is using the Gem installer.

```sh
gem install MuranoCLI
```

- If you are upgrading from a `1.*` version, uninstall the old versions first.

```sh
gem uninstall MuranoCLI MrMurano
```

- If you would like to install a specific version, such as the older,
  pre-Murano CLI tool, you can specify the version to install.

```sh
gem install MuranoCLI -v 2.2.4
```

- To update to the latest gem (rather than installing a new gem side by
  side with an older version of the same gem), update it.

```sh
gem update MuranoCLI
```

You will likely need to be root for the above commands. If you would rather
not install as root, you can install gems in the user directory.

```sh
gem install MuranoCLI --user-install
```

Your `PATH` may need to be updated to find the installed `murano` command.
See the [Ruby Gem FAQ](http://guides.rubygems.org/faqs/#user-install).

- In short, you need to add the output of
  `ruby -rubygems -e 'puts Gem.user_dir'` to your `PATH`.

  E.g., you may want to add this to your `~/.bashrc` file:

  `export PATH=$PATH:$(ruby -rubygems -e 'puts Gem.user_dir')`

#### Working With Different Versions of MuranoCLI

The `murano` command line tool is a Ruby gem and, as such, you can install
different versions of MuranoCLI and choose which one to execute.

The following example shows how you can reference a specific version of the
`murano` gem:

```sh
$ gem list MuranoCLI --local

*** LOCAL GEMS ***

MuranoCLI (3.0.1, 2.2.4)

$ murano --version
murano 3.0.1

$ murano _2.2.4_ --version
murano 2.2.4
```

Note: Not all OSes support multiple versions and will only execute the
latest Gem installed. In this case, you will need to uninstall newer
versions of MuranoCLI in order to use older versions.

### Windows Install

The MuranoCLI gem will install on Windows.

There is also a single Windows binary Setup installer available in
[releases](https://github.com/exosite/MuranoCLI/releases).

If you do not already use Ruby on Windows, then you should use the binary
installer.

When upgrading, it is best to run the uninstaller for the old version
before installing the new version.

## Features

### Logs

You can monitor the log messages from your Application by running
`murano logs application --follow`.

Or quickly get the last few logs with simply `murano logs application`.

MuranoCLI does a few things to make the log output easier to follow.

- It adds color to easily see where each log message starts.

- It reformats the timestamps to be in local time.

- It finds JSON blobs and pretty prints them.

Each of these options can be disabled with command line options.

### CORS

If you are developing a UI on separate services and need cross-origin
resource sharing, you will need to set the
[CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing) options.

The current CORS options can be fetched with `murano cors`.

There are three different ways to configure CORS.

The first and preferred way is to add your CORS options to a file named
`cors.yaml`.

The second and third options are to put the CORS options in your project file.

- In the `routes` section, add a `cors` sub-section with either the name of
  the file to read, or the CORS options inline.

  ```yaml
  routes:
    cors: my_cors_file.json
  ```

  OR:

  ```yaml
  routes:
    cors: {"origin": true}
  ```

Then use `murano cors set` to push these options up to your application.

### Writing Routes (a.k.a. Endpoints)

All of the routes that you create in your application are identified
by their method and path. You set this with the following line:

```lua
--#ENDPOINT METHOD PATH
```

Optionally, you can set what the expected content type is, too.
(If you don't set this, it defaults to `application/json`.)

```lua
--#ENDPOINT METHOD PATH CONTENT_TYPE
```

Here is an example of a route that puts CSV data:

```lua
--#ENDPOINT PUT /api/upload text/csv
```

After the magic header, add the script to handle the route.

Since many routes end up being a couple of lines or less,
you can put multiple routes into a single file.

A routes file might look like this:

```lua
--#ENDPOINT GET /api/somedata
return Tsdb.query(…)

--#ENDPOINT PUT /api/somedata text/csv
return myimport_module.import(request)

--#ENDPOINT DELETE /api/startover
return Tsdb.deleteAll()
```

### Writing Service Event Handlers

Each event handler in your project is identified by which service
it watches and which event in that service triggers the script.

This is set with the following magic header line:

```lua
--#EVENT SERVICE EVENT
```

To make working with the Product ID easier, you can use the magic
variable `{product.id}` instead of the actual Product ID.
You can use this variable in both the filename and the magic header.

For example, the event handler that processes all data coming from your
devices might look like:

```lua
--#EVENT {product.id} event
local stamped = nil
if data.api == "record" then
  stamped = tostring(data.value[1]) .. 's'
end
Tsdb.write{
  tags = {sn=data.device_sn},
  metrics = {[data.alias] = tonumber(data.value[2])},
  ts = stamped
}
```

### MURANO_CONFIGFILE Environment Variable and Dotenv

The environment variable `MURANO_CONFIGFILE` is checked for an additional config
to load. This, in conjunction with [dotenv](https://github.com/bkeepers/dotenv)
support, allows you to easily switch between development, staging, and production
setups.

To use this, write the three Application IDs and three Product IDs for your three
deployments into the three files, `.murano.dev`, `.murano.stg`, and `.murano.prod`.

Then, write the `.env` file to point at the system you're currently working on.

The files for this are then:

```sh
cat >> .murano.dev <<EOF
[application]
id=AAAAAAAA
[product]
id=BBBBBBBB
EOF

cat >> .murano.stg <<EOF
[application]
id=LLLLLLLL
[product]
id=MMMMMMMM
EOF

cat >> .murano.prod <<EOF
[application]
id=XXXXXXXX
[product]
id=YYYYYYYY
EOF

cat > .env <<EOF
MURANO_CONFIGFILE=.murano.dev
EOF
```

This also allows for keeping private things in a separate config file and
having the shared things checked into source control.

### Direct Service Access

To aid with debugging, MuranoCLI has direct access to some of the services
in an application.

Currently these are:

- Keystore: `murano keystore`

- TSDB: `murano tsdb`

### Output Format

Many sub-commands respect the `outformat` setting. This lets you switch the
output between YAML, JSON, Ruby, CSV, and pretty tables. (Not all formats
work with all commands, however.)

```
> murano tsdb product list
> murano tsdb product list -c outformat=csv
> murano tsdb product list -c outformat=json
> murano tsdb product list -c outformat=yaml
> murano tsdb product list -c outformat=pp
```

### Product Content Area

MuranoCLI can manage the content area for a product. This area is a place to
store files for use by devices. Storing firmware images for over-the-air
updates is one typical use, although any kind of fleet-wide data that devices
may need to download can be stored here.

Once the `product.id` is set, the content for that product can be accessed
with the following commands:

```
> murano content list
> murano content upload
> murano content info
> murano content delete
> murano content download
```

Call `murano` with `--help` for more details.

## Developing

MuranoCLI uses [git flow](https://github.com/nvie/gitflow#getting-started) for
[managing branches](http://nvie.com/posts/a-successful-git-branching-model/).

MuranoCLI also uses [bundler](http://bundler.io).

When submitting pull requests, please do them against the `develop` branch.

### Testing

All test for MuranoCLI are done with rspec.

The tests are internal (`--tag ~cmd`) or command (`--tag cmd`).

- The internal tests are for the objects that build up the internals.

- The command tests run `murano` from the shell and are for testing
  the user facing components.

  A subset of the command tests work with the live Murano servers
  (`--tag needs_password`).

To use the live tests, the following environment variables need to be set:

- `MURANO_CONFIGFILE`:
  A Config with the user.name, business.id, and net.host for the integration tests.

- `MURANO_PASSWORD`:
  Password for the user.name above.

A free account on [Murano](https://exosite.com/signup/) is sufficient for
these tests.

