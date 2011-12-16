Release: RabbitMQ 2.7.1

Release Highlights
==================

server
------
bug fixes
- the broker sometimes hung when recovering queues on startup
- broker-generated queue names did not conform to AMQP syntax rules
- broker sometimes hung when closing channels and connection from multiple
  threads
- high availability master nodes didn't recover properly
- long-running brokers could suddenly crash due to global unique identifiers
  not being unique enough
- broker could crash if clients are attempting to (re)connect before the broker
  is properly started
- there was a slow memory leak in mirrored queues with persistent (or confirmed)
  messages
- queue equivalence check did not properly detect extremely different arguments
- rabbitmqctl list_connections could return incomplete information
- promotion of a slave to master could fail when confirms are enabled
- guaranteed multicast could fail under some circumstances with multiple
  participating nodes
- some functions were used that are not in the latest Erlang release

enhancements
- rabbitmqctl eval <expr> evaluates arbitrary Erlang expressions in the broker
  node
- deletion of exchanges or queues with many bindings is more efficient

java client
-----------
bug fixes
- resources were not recovered if ConnectionFactory failed to connect
- defaults for the ConnectionFactory class were not public
- part of the Java client API was hidden, causing application build errors
- interrupts were mishandled in the Java threading logic

.net client
-----------
bug fixes
- session autoclose could fail with AlreadyClosedException

plugins
-------
bug fixes
- consistent-hash-exchange mis-routed messages when handling multiple exchanges
- some tests and Erlang patches depended upon functions not in the latest Erlang
  release

management plugin
-----------------
bug fixes
- management plug-in could crash if it had limited permissions
- overview could sometimes crash when another node starts up or shuts down
- statistics could be lost when nodes failed
- shovels were not displayed if they were in an undefined state
- slave synchronisation could sometimes be misrepresented on the management
  interface
- encoding of underscore in URL properties was incomplete
- management interface could break if there were html syntax characters in names

enhancements
- rate of change of queue lengths has been added to the management user
  interface
- minor improvements to shovel information formatting

auth-backend-ldap plugin
------------------------
enhancements
- accept a broader class of group objects on in_group filter

STOMP adapter
-------------
bug fixes
- temporary reply-to queues were not re-usable
- duplicate headers were generated in some MESSAGE frames
- functions were used not in the latest Erlang release

build and packaging
-------------------
bug fixes
- rabbitmq-server Mac OSx portfile was incorrectly built
- maven bundle for Java client was not published to maven central


Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply install
the new version. All configuration and persistent message data is retained.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install the new
version on all the nodes and follow the instructions at
http://www.rabbitmq.com/clustering.html#upgrading .

To upgrade RabbitMQ from release 2.1.0, first upgrade to 2.1.1 (all data will be
retained), and then to the current version as described above.

When upgrading from RabbitMQ versions prior to 2.1.0, the existing data will be
moved to a backup location and a fresh, empty database will be created. A
warning is recorded in the logs. If your RabbitMQ installation contains
important data then we recommend you contact <support at rabbitmq.com> for
assistance with the upgrade.
