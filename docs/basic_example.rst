#######################
Basic MuranoCLI Example
#######################

Learn Murano the Easy Way
=========================

This document illustrates how to setup a very basic Murano project.

It shows how to use the Murano CLI tool (also called "MuranoCLI", or
just "MurCLI") to create an Application and Product, and how to send
data to the Product that gets processed by the Application.

Prerequisites
=============

It is assumed that you have already created a Murano business account,
and that you have installed MurCLI on your local machine.

- To sign up for a free Murano business account, visit:

  https://exosite.com/signup/

- To install MurCLI, run:

  ``gem install MuranoCLI``

If you need installation help, look at the `README
<https://github.com/exosite/MuranoCLI#install>`__.

Start Fresh
===========

You can skip this section if you've never setup a business before.

But if you've already created a business, and if you've already
created an Application and/or Product for it, you can clean up
that business so we can start over.

First, list your businesses and find the one you want to reset. E.g.,

.. code-block:: text

    $ murano business list

    +------------------+-------+-------------------+
    | bizid            | role  | name              |
    +------------------+-------+-------------------+
    | 4o54fc55olth85mi | owner | My First Business |
    | fu5rse4xdww2ke29 | admin | Collaborative Biz |
    | ct7rmoz3hu34ygb9 | owner | Another of My Biz |
    +------------------+-------+-------------------+

NOTE: If you have never used MurCLI before, or if you've logged out
of Murano, MurCLI will tell you to logon first. E.g.,

.. code-block:: text

    $ murano business list

    No Murano user account found.
    Please login using `murano login` or `murano init`.
    Or set your password with `murano password set <username>`.

Next, remove all solutions (Applications and Products) from that project.

.. code-block:: text

    $ murano solutions expunge -y -c business.id=ct7rmoz3hu34ygb9

    Deleted 2 solutions

Logout of Murano. This removes your username and password so
that MurCLI will ask you to reenter your username and password.

.. code-block:: text

    $ murano logout

You might also have environment variables set. Clear those for
the sake of this walk-through.

.. code-block:: text

    $ export MURANO_CONFIGFILE=
    $ export MURANO_PASSWORD=

Create a New Project
====================

Create a new directory for your project.

.. code-block:: text

    $ mkdir ~/murano/projects/basic_test

    $ cd ~/murano/projects/basic_test

You can run MurCLI commands now, but they won't be useful until you ``init``. E.g.,

.. code-block:: text

    $ murano show

    No Murano user account found.
    Please login using `murano login` or `murano init`.
    Or set your password with `murano password set <username>`.

Run the init command to easily wire the new project to your existing business,
to create an Application and Product, and to setup local directories and files.

The init command will link the Product to the Application so that data sent
to the Product is passed along to the Application.

Here's an example use of the init command.

.. code-block:: text

    $ murano init

    Creating project at /user/home/murano/projects/basic_test

    No Murano user account found. Please login.
    User name: exositement@exosite.com
    Password: *************
    1. My First Business  2. Collaborative Biz  3. Another of My Biz
    Please select the Business to use:
    3

    This business does not have any applications. Let's create one

    Please enter the Application name: basicexample

    Created new Application: basicexample <v3sl941hifticggc0>

    This business does not have any products. Let's create one

    Please enter the Product name: exampleprod

    Created new Product: exampleprod <n51cq3fea5zc40cs4>

    Linked ‘exampleprod’ to ‘basicexample’

    Created default event handler

    Writing Project file to basictest.murano

    Created default directories

    Synced 4 items

    Success!

             Business ID: ct7rmoz3hu34ygb9
          Application ID: v3sl941hifticggc0
              Product ID: n51cq3fea5zc40cs4

You'll notice that ``init`` downloaded a few files from Murano that are
automatically created when you create solutions and link them.

For instance, you should see a handful of Lua scripts in the ``services``
directory.

.. code-block:: text

    $ ls services

    n51cq3fea5zc40cs4_event.lua  timer_timer.lua  tsdb_exportJob.lua  user_account.lua

Update the Data Event Handler
=============================

Let's edit the Product data event handler so that it spits out a log message
when it gets data from the Product. The event handler is named using the
Product ID, so grab that, and use the ID to make the name of the Lua script.

.. code-block:: text

    $ PRODUCT_ID=$(murano config product.id)

    $ PROD_EVENT="services/${PRODUCT_ID}_event.lua"

    $ echo ${PROD_EVENT}

    services/n51cq3fea5zc40cs4_event.lua

You'll notice that Murano already created a simple event handler.

.. code-block:: text

    $ cat ${PROD_EVENT}

    --#EVENT n51cq3fea5zc40cs4 event
    print(event)

Now, overwrite the event handler with something similar. We just
want to show how easy it is to update the event handler.

.. code-block:: text

    $ cat > ${PROD_EVENT} << EOF
    --#EVENT ${PRODUCT_ID} event
    print("EVENT: " .. to_json(event))
    EOF

NOTE: The ``--#EVENT`` header is mandatory. It tells Murano
how to interpret the snippet of Lua code.

If you run the ``status`` command, you should see that there's now one
file modified locally (the event handler that we just edited) that is
not synced with the corresponding event handler on Murano.

.. code-block:: text

    $ murano status

    Nothing new locally
    Nothing new remotely
    Items that differ:
     M E  services/n51cq3fea5zc40cs4_event.lua

Run the ``syncup`` command to upload any modified files to Murano,
overwriting what is on Murano.

.. code-block:: text

    $ murano syncup

Create and Provision a New Device
=================================

In order to do something useful, we need to create a device,
that is attached to the Product, that can generate data.

You'll notice that the new Product does not have any devices.

.. code-block:: text

    $ murano device list

    Did not find any devices

Create a device. We can use whatever identifier we want, so
just grab a random UUID.

.. code-block:: text

    $ SOME_ID=$(uuidgen)

    $ murano device enable ${SOME_ID}

    $ murano device list

    +--------------------------------------+-------------+--------+
    | Identifier                           | Status      | Online |
    +--------------------------------------+-------------+--------+
    | 1af384dd-57ba-4f13-9d89-45dbcbf207de | whitelisted | false  |
    +--------------------------------------+-------------+--------+

Provision the device. Murano generates and returns a CIK
that we need to remember so that we can authenticate as
the device when making calls on its behalf.

.. code-block:: text

    $ CIK=$(murano product device activate ${SOME_ID})

    $ echo ${CIK}

    MJzNuMqPDs7UADLriMlHK10dClv7cx46uLSkJLSw

    $ murano device list

    +--------------------------------------+-------------+--------+
    | Identifier                           | Status      | Online |
    +--------------------------------------+-------------+--------+
    | 1af384dd-57ba-4f13-9d89-45dbcbf207de | provisioned | false  |
    +--------------------------------------+-------------+--------+

Generate Device Data
====================

Each solution (Application or Product) has its own URI.
We need the Product's URI in order to interact with Murano
on behalf of the device.

Make a local variable for the Product URI.

.. code-block:: text

    $ PRODUCT_URI=$(murano domain product --brief --no-progress)

NOTE: We need to use the ``--no-progress`` option, otherwise MurCLI
will display a progress bar that contaminates the captured output.

Write data to the device. E.g., let's write a very cold temperature value.

.. code-block:: text

    $ curl -si -k https://${PRODUCT_URI}/onep:v1/stack/alias \
        -H "X-Exosite-CIK: ${CIK}" \
        -H "Accept: application/x-www-form-urlencoded; charset=utf-8" \
        -d reports='{"temperature": -40.0}' \
        -i -v -w "%{http_code}"

    [VERBOSE OUTPUT OMITTED]
    204

Verify that the data was passed from the Product to the Application and
processed how we indicated in the event handler (which is to log it).

.. code-block:: text

    $ murano logs --application

    DEBUG [n51cq3fea5zc40cs4_event] 2017-07-26T11:44:57.000-05:00:
    EVENT: {
        "connection_id":"D2bzFD6HSV3ih56dbswY",
        "identity":"1af384dd-57ba-4f13-9d89-45dbcbf207de",
        "ip":"123.234.012.234",
        "protocol":"onep",
        "timestamp":1.501087497424287e+15,
        "type":"provisioned"
        }

    DEBUG [n51cq3fea5zc40cs4_event] 2017-07-26T14:09:30.000-05:00:
    EVENT: {
        "connection_id":"QWJeZcpXej5h5f5hwdLY",
        "identity":"1af384dd-57ba-4f13-9d89-45dbcbf207de",
        "ip":"123.234.012.234",
        "payload":[{
            "timestamp":1.501096170486053e+15,
            "values":{
                "reports":"{\"temperature\": -40.0}"}
        }],
        "protocol":"onep",
        "timestamp":1.501096170487898e+15,
        "type":"data_in"
        }

Success! You should see the ``temperature`` value in the last log message.

You'll notice that the Product does not generate any log messages.

.. code-block:: text

    $ murano logs --product

    # [NO OUTPUT]

Create a Resource
=================

Bonus step! Create a resource for your data.

NOTE: The write operation works regardless of having a resource defined.

Create a resources file that describes the data. E.g.,

.. code-block:: text

    $ cat > specs/resources.yaml << EOF
    ---
    temperature:
      allowed: []
      format: number
      settable: false
      unit: ''
    EOF

Upload the resources to Murano.

.. code-block:: text

    $ murano syncup

And write more data.

.. code-block:: text

    $ curl -si -k https://${PRODUCT_URI}/onep:v1/stack/alias \
        -H "X-Exosite-CIK: ${CIK}" \
        -H "Accept: application/x-www-form-urlencoded; charset=utf-8" \
        -d raw_data='{"temperature": -19.9}' \
        -i -v -w "%{http_code}"

Verify that you see a new event in the log.

.. code-block:: text

    $ murano logs --application

    DEBUG [n51cq3fea5zc40cs4_event] 2017-07-26T11:44:57.000-05:00:
    EVENT: {
        "connection_id":"D2bzFD6HSV3ih56dbswY",
        "identity":"1af384dd-57ba-4f13-9d89-45dbcbf207de",
        "ip":"123.234.012.234",
        "protocol":"onep",
        "timestamp":1.501087497424287e+15,
        "type":"provisioned"
        }

    DEBUG [n51cq3fea5zc40cs4_event] 2017-07-26T14:09:30.000-05:00:
    EVENT: {
        "connection_id":"QWJeZcpXej5h5f5hwdLY",
        "identity":"1af384dd-57ba-4f13-9d89-45dbcbf207de",
        "ip":"123.234.012.234",
        "payload":[{
            "timestamp":1.501096170486053e+15,
            "values":{
                "reports":"{\"temperature\": -40.0}"}
        }],
        "protocol":"onep",
        "timestamp":1.501096170487898e+15,
        "type":"data_in"
        }

    DEBUG [n51cq3fea5zc40cs4_event] 2017-07-26T14:16:00.000-05:00:
    EVENT: {
        "connection_id":"3DD9rAZ95bgro5O0kGGD",
        "identity":"1af384dd-57ba-4f13-9d89-45dbcbf207de",
        "ip":"123.234.012.234",
        "payload":[{
            "timestamp":1.501096560116624e+15,
            "values":{
                "raw_data":"{\"temperature\": -19.9}"}
        }],
        "protocol":"onep",
        "timestamp":1.501096560118335e+15,
        "type":"data_in"
        }

*Et Voilà!*

Congratulations of your first, very basic Murano project!

