############################
Murano CLI WebSocket Servers
############################

========
Overview
========

There are 2 WebSocket servers under ``spec/fixtures/websocket/``:

- ``wss-fake-logs.rb``: Run this for developing. It'll spit out a fake log record every second to any client that connect.

- ``wss-echo.rb``: The spec tests use this to test the new logs command code. Whatever the server receives on stdin it just echos to any client that's connected.

=====
Usage
=====

From one terminal, start the fake logs server:

.. code-block:: bash

  cd /path/to/exosite-murcli/spec/fixtures/websocket

  ./wss-fake-logs.rb

From another terminal, you can use any WebSocket client.

\1. Using Murano CLI.:

.. code-block:: bash

  murano logs -f -c net.host=127.0.0.1:4180 -c net.protocol=http --tracking --trace

\2. Using ``esphen/wsta``:

.. code-block:: bash

  # Locally
  wsta --ping 10 "ws://127.0.0.1:4180/path/does/not/matter?limit=1000"

  # Against BizAPI.
  wsta --ping 10 "wss://bizapi-dev.hosted.exosite.io/api/v1/solution/m1ti0dv29pb340000/logs?token=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX&limit=1000"

\3. Using ``hashrocket/ws``:

.. code-block:: bash

  ws "wss://bizapi-dev.hosted.exosite.io/api/v1/solution/m1ti0dv29pb340000/logs?token=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX&limit=1000"

-----------------
Token Shenanigans
-----------------

To run ``murano logs`` locally, against 127.0.0.1, you'll probably
need to disable the token mechanism.

Add this to ``lib/MrMurano/Account.rb``::

    def token_fetch
      @token = 'XXX'
      return

=========================
Non-Murano CLI WS Clients
=========================

---------------
``esphen/wsta``
---------------

- ``esphen/wsta`` is a WebSocket CLI client written in Rust.

  As of late 2017, it's 1 year old and appears to be the most sophisticated client.

  https://github.com/esphen/wsta

To install:

.. code-block:: bash

  sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/esphen/xUbuntu_16.04/ /' > /etc/apt/sources.list.d/wsta.list"
  wget -nv https://download.opensuse.org/repositories/home:esphen/xUbuntu_16.04/Release.key -O Release.key
  sudo apt-key add - < Release.key
  rm Release.key
  sudo apt-get update
  sudo apt-get install wsta

-----------------
``hashrocket/ws``
-----------------

- ``hashrocket/ws`` is WebSocket CLI client written in Go.

  As of late 2017, it's 1 year old.

  https://github.com/hashrocket/ws

To install:

.. code-block:: bash

  go get -u github.com/hashrocket/ws

---------------------------------------
Browser-based "Simple WebSocket Client"
---------------------------------------

https://chrome.google.com/webstore/detail/simple-websocket-client/pfdhoblngboilpfeibdedpjgfnlcodoo?hl=en

