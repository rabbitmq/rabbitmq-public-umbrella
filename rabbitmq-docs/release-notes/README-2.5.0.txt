Release: RabbitMQ 2.5.0

Release Highlights
==================

server
------
bug fixes
- reduce complexity of recovery, significantly improving startup times
  when there are large numbers of exchanges or bindings
- recover bindings between durable queues and non-durable exchanges
  on restart of individual cluster nodes
- do not read messages off disk in the x-message-ttl logic. This could
  severely impact performance when many queues expired messages
  (near)simultaneously.
- resolve a timer issue that could impact performance when under high
  load and memory pressure
- make source code compilable with latest Erlang release (R14B03)
- assert x-message-ttl equivalence on queue redeclaration

enhancements
- tracing facility for incoming and outgoing messages - see <url>
- optionally serialise events for exchange types
- detect available memory on OpenBSD
- add Windows service description
- improve inbound network performance
- improve routing performance

java client
-----------
bug fixes
- compile under Java 1.5 (again)

enhancements
- new API, employing command objects and the builder pattern. See
  <url>

.net client
-----------
bug fixes
- make method id of 'exchange.unbind-ok' match definition in the
  broker, so the client lib can recognise that command.
- WCF bindings specified in configuration files are no longer ignored

enhancements
- allow larger than default message sizes in WCF

management plugin
-----------------
bug fixes
- handle race when starting the management plug-in on multiple cluster
  nodes, which in some rare (but quite reproducible) circumstances
  could cause some of the brokers to crash

enhancements

build and packaging
-------------------
bug fixes
- fix breakage in /etc/init.d/rabbitmq-server rotate-logs command

enhancements
- <describe highlights of new build system, particularly its effect on
  plug-ins (naming, versions, dependencies, build, ...); don't forget
  to mention the resulting change in plug-in names and thus config entries>
- do not require access to www.docbook.org when building the server
  w/o docbook installed
- get rid of some warnings in the .net client build


Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install
the new version on all the nodes and follow these instructions:
    http://www.rabbitmq.com/clustering.html#upgrading
All configuration and persistent message data is retained.

To upgrade a non-clustered RabbitMQ from release 2.1.0, first upgrade
to 2.1.1 (which retains all data), and then to the current version as
described above.

To upgrade a clustered RabbitMQ prior to 2.1.1 or a stand-alone broker
from releases prior to 2.1.0, if the RabbitMQ installation does not
contain any important data then simply install the new
version. RabbitMQ will move the existing data to a backup location
before creating a fresh, empty database. A warning is recorded in the
logs. If your RabbitMQ installation contains important data then we
recommend you contact support@rabbitmq.com for assistance with the
upgrade.
