########################
Murano CLI Jenkins Notes
########################

.. code-block:: bash

  for ruby_vers in \
    "2.5.0" \
    "2.4.3" \
    "2.3.6" \
    "2.2.9" \


  m4 \
    --define=RUBY_VERSION="2.3.6" \
      dockers/Dockerfile.m4 \
    > dockers/Dockerfile.


    &> /dev/null
  sudo /etc/init.d/postgresql restart


=============================
Jenkins project configuration
=============================

- Jenkins project:

  https://jenkins.exosite.com/job/MuranoCLI/job/Murano%20CLI%20Tests%20-%20Ruby%202.3/configure

- General configuration

  - Project name: ``Murano CLI Tests - Ruby 2.3``

  - Discard old builds ``✓``

      - Strategy: ``Log Rotation``

        - Days to keep builds: ``60``

        - Max # builds to keep: ``5``

  - GitHub project ``✓``

    - Project url: https://github.com/exosite/MuranoCLI/

- Source Code Management

  - Git ``✓``

    - Repositories

      - Repository URL: https://github.com/exosite/MuranoCLI.git

      - Credentials: ``FIXME``: We'll need this to go private.

    - Branches to build

      - Branch Specifier (blank for 'any')	: ``*/feature/Dockerize``

- Build Triggers

  - GitHub hook trigger for GITScm polling ``✓``

- Build Environment

  - Build inside a Docker container ``✓``

    - Docker image to use

      - Build from Dockerfile ``✓``

        - path to docker context: ``.``

        - Dockerfile: ``./dockers/Dockerfile``

      - [Click Advanced]

        - Volumes

          - Add

            - Path on host: ``$WORKSPACE/report``

            - Path inside container: ``/app/report``

          - Add

            - Path on host: ``$WORKSPACE/coverage``

            - Path inside container: ``/app/coverage``

        - User group: ``root``

        - Container start command: ``/bin/cat``

        - Network bridge: ``bridge``

  - Inject passwords to the build as environment variables ``✓``

    - Job passwords

      - Add

        - Name: ``LANDON_PASSWORD``

        - Password: ``****************``

      - Add

        - Name: ``LANDON_USERNAME``

        - Password: ``****************``

- Build

  - Execute shell

    - Command::

      #!/bin/bash
      /app/dockers/docker-test.sh

- Post-build Actions

  - Publish HTML reports

    - Reports

      - Add

        - HTML directory to archive: ``report``

        - Index page[s]: ``index-2_2_7.html,index-2_3_4.html,index-2_4_1.html``

        - Report title: ``RSpec Report``

      - Add

        - HTML directory to archive: ``coverage``

        - Index page[s]: ``index.html``

        - Report title: ``Coverage Report``

- E-mail Notification

  - Recipients: ``landonbouma@exosite.com``

