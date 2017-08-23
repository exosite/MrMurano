# Murano Command Line Interface (CLI)

[![Gem
Version](https://badge.fury.io/rb/MuranoCLI.svg)](https://badge.fury.io/rb/MuranoCLI)
[![Build Status](https://travis-ci.org/exosite/MuranoCLI.svg?branch=master)](https://travis-ci.org/exosite/MuranoCLI)
[![Inline docs](http://inch-ci.org/github/exosite/MuranoCLI.svg?branch=master)](http://inch-ci.org/github/exosite/MuranoCLI)

Do more from the command line with [Murano](https://exosite.com/platform/).

MuranoCLI is the command-line tool that interacts with Murano and makes
different tasks easier. MuranoCLI makes it easy to deploy code to a solution,
import many product definitions at once, set up endpoints and APIs, and more.

MuranoCLI works around the idea of syncing, much like rsync. Files from your
project directory are synced up (or down) from Murano.


## Usage

```
mkdir myproject
cd myproject
murano init
```

Update `myproject.murano` with the info about your project.

If this is a new project, you will also need to run `murano assign set` to
connect the product and solution.

If this is an existing project, you want to run `murano syncdown -V` after
running `murano init`.

Now do stuff, see what changed: `murano status` or `murano diff`.
Then deploy with `murano syncup`

### To start a brand new project step-by-step
There are a few steps and pieces to getting a solution with a product up
and running in Murano. Here is the list.

- Pick a business: `murano business list`.
  - If this is the first time you've run `murano` it will ask for your
    Murano username and password.
  - If you need to change change accounts, `murano config user.name` and
    `murano password --help`.
- Choose the desired business id: `murano config business.id ZZZZZZZZZ`
- Create a product: `murano product create myawesomeproduct --save`
  - Another option would be to choose an existing product:
    `murano config product.id XXXXXXXX`
- Add resource aliases to specs/resources.yaml
- Sync the product definition up: `murano syncup -V --specs`
- Create a solution: `murano solution create myawesomesolution --save`
- Sync solution code up: `murano syncup -V`
- Assign the product to the solution: `murano assign set`

Do stuff, see what changed: `murano status` or `murano diff`.
Then deploy with `murano syncup`

## Install

### Gem Install (Linux and Macos)

When upgrading from a 1.\* version to a 2.0, you should uninstall the old
versions first.
```sh
> gem uninstall MuranoCLI MrMurano
```

And then install:

```sh
> gem install MuranoCLI
```
Or to install a specific version:
```sh
> gem install MuranoCLI -v 2.2.4
```
Or to update to the latest:
```sh
> gem update MuranoCLI
```

You will likely need to be root for the above commands. If you would rather
not install as root, you can install gems in the user directory.

```sh
> gem install MuranoCLI --user-install
```

Your `PATH` may need to be updated to find the installed `murano` command.
See the [Ruby Gem FAQ](http://guides.rubygems.org/faqs/#user-install).
In short, you need to add the output of `ruby -rubygems -e 'puts Gem.user_dir'`
to your `PATH`.

#### Working With Different Versions of MuranoCLI

The `murano` command line tool is a Ruby gem and, as such, multiple versions
of MuranoCLI can be installed and executed concurrently.

To illustrate working with multiple versions of MuranoCLI, the following
code block shows how one can make reference to a specific version of the
`murano` gem:

```sh
$ gem list MuranoCLI --local
*** LOCAL GEMS ***
MuranoCLI (2.2.3, 2.1.0, 2.0.0)

$ murano --version
murano 2.2.3

$ murano _2.1.0_ --version
murano 2.1.0
```

### Windows Install

The MuranoCLI gem will install on Windows. There is also a single Windows
binary Setup installer available in
[releases](https://github.com/exosite/MuranoCLI/releases).

If you do not already use Ruby on Windows, then you should use the binary
installer.

When upgrading, it is best to run the uninstaller for the old version before
installing the new version.


## Features

### Project File

### Logs

You can monitor the log messages from your solution with the
`murano logs --follow`. Or quickly get the last few with `murano logs`.

MuranoCLI does a few things to make your log output easier to follow.
- Adds color to easily see where each log message starts.
- Reformats the timestamps to be in local time.
- Finds JSON blobs and pretty prints them.

All of these can be toggled with command line options.

### CORS

If you are developing you UI on separate services and you need cross-origin
resource sharing, you will need to set the
[CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing) options.

The current CORS options can be fetched with `murano cors`.

There are three options for setting, the first and preferred way is to put
your CORS options into a file named `cors.yaml`.

Second and third are to put the CORS options in your project file. In the
`routes` section, add a `cors` sub-section with either the name of the file
to read, or the CORS options inline.

```yaml
routes:
  cors: my_cors_file.json
```
OR:
```yaml
routes:
  cors: {"origin": true}
```

Then use `murano cors set` to push these options up to your solution.

### Writing Routes (or endpoints)

All of the routes that you create in your solution are identified by their
method and path. You set this with the following line:

```lua
--#ENDPOINT METHOD PATH
```

Optionally, you can set what the expected content type is too. (If you don't
set this, the value is `application/json`.)

```lua
--#ENDPOINT METHOD PATH CONTENT_TYPE
```

An example of a route that puts CSV data:
```lua
--#ENDPOINT PUT /api/upload text/csv
```

After this header line, the script to handle the route follows. Since many
routes end up being a couple of lines or less, you can put multiple routes
into a single file.

Which looks like this:
```lua
--#ENDPOINT GET /api/somedata
return Tsdb.query(…)

--#ENDPOINT PUT /api/somedata text/csv
return myimport_module.import(request)

--#ENDPOINT DELETE /api/startover
return Tsdb.deleteAll()
```

### Writing Service Event Handlers

All of the event handlers you add to your solution are identified by which
service they are watching and which event in that service triggers the
script.

This is set with the following line:
```lua
--#EVENT SERVICE EVENT
```

For example, the event handler that processes all data coming from your
devices could be:
```lua
--#EVENT device datapoint
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

### MURANO_CONFIGFILE environment and Dotenv

The environment variable `MURANO_CONFIGFILE` is checked for an additional config
to load. This, in conjunction with [dotenv](https://github.com/bkeepers/dotenv)
support, allows for easily switching between development, staging, and production
setups.

To use this, write the three solution ids into `.murano.dev`, `.murano.stg`,
and `.murano.prod`. Then write the `.env` file to point at the system you're
currently working on.

The files for this are then:
```sh
cat >> .murano.dev <<EOF
[solution]
id=AAAAAAAA
EOF

cat >> .murano.stg <<EOF
[solution]
id=BBBBBBBB
EOF

cat >> .murano.prod <<EOF
[solution]
id=CCCCCCCC
EOF

cat > .env <<EOF
MURANO_CONFIGFILE=.murano.dev
EOF
```

This also allows for keeping private things in a separate config file and
having the shared things checked into source control.

### Direct Service Access

To aid with debugging, MuranoCLI has direct access to some of the services
in a solution.

Currently these are:
- Keystore: `murano keystore`
- TSDB: `murano tsdb`

### Output Format

Many sub-commands respect the `outformat` setting. This lets you switch the
output between YAML, JSON, Ruby, CSV, and pretty tables. Not all formats
work with all commands.

```
> murano tsdb product list
> murano tsdb product list -c outformat=csv
> murano tsdb product list -c outformat=json
> murano tsdb product list -c outformat=yaml
> murano tsdb product list -c outformat=pp
```

### Product Content Area

MuranoCLI can manage the content area for a product. This area is a place to
store files for use by devices. Typically holding firmware images for
Over-The-Air updating. Although any kind of fleet wide data that devices
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

Call them with `--help` for details.

## Developing

MuranoCLI uses [git flow](https://github.com/nvie/gitflow#getting-started) for
[managing branches](http://nvie.com/posts/a-successful-git-branching-model/).

MuranoCLI also uses [bundler](http://bundler.io).

When submitting pull requests, please do them against the develop branch.

### Tests
All test for MuranoCLI are done with rspec.

The tests are internal (`--tag ~cmd`) or command (`--tag cmd`). The internal
tests are for the objects that build up the internals. The command tests run
`murano` from the shell and are for testing the user facing components. A
subset of the command tests work with the live Murano servers (`--tag needs_password`).

To use the live tests, the following environment variables need to be set:
- `MURANO_CONFIGFILE`: A Config with the user.name, business.id, and net.host
  for the integration tests.
- `MURANO_PASSWORD`: Password for the user.name above.

A free account on [Murano](https://exosite.com/signup/) is sufficient for
these tests.

