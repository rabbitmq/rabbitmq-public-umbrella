Release: RabbitMQ 2.4.1

Release Highlights
==================

FIXME: remove [bug NNNNN] annotations

server
------
bug fixes
- [bug 24008] fix issue when upgrading following an unclean broker shutdown
- [bug 24007] prevent "rabbitmqctl wait" from waiting forever in
  certain circumstances
- [bug 23997] the broker can be run on Erlang R12B-3 again
- [bug 23998][bug 23937] various other fixes

enhancements
- [bug 23425] upgrades in clusters. See
    http://www.rabbitmq.com/clustering.html#upgrading
- [bug 23968] improve memory usage when dealing with persistent
  messages waiting on acks from consumers
- [bug 24020] a warning is emitted about the old config location only
  if the new one does not exist


java client
-----------
enhancements
- [bug 24000] remove dependency on javax.security.sasl, thus improving
  compatibility with Android and WebSphere


.net client
-----------
bug fixes
- [bug 23980] the client can be built on .NET 2.0 again


management plugin
-----------------
bug fixes
- [bug 23989] fix issue that would cause non-admin users to be
  repeatedly prompted for their password when viewing the queues page


STOMP plugin
------------
bug fixes
- [bug 24012] the plugin works on Erlang R12 again


build and packaging
-------------------
bug fixes
- [bug 23993] the OCF script works correctly when specifying an
  alternative config file


Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a non-clustered RabbitMQ from release 2.1.0, first upgrade
to 2.1.1 (which retains all data), and then to the current version as
described above.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install
the new version on all the nodes and follow these instructions:
    http://www.rabbitmq.com/clustering.html#upgrading
All configuration and persistent message data is retained.

To upgrade a clustered RabbitMQ prior to 2.1.1 or a stand-alone broker
from releases prior to 2.1.0, if the RabbitMQ installation does not
contain any important data then simply install the new
version. RabbitMQ will move the existing data to a backup location
before creating a fresh, empty database. A warning is recorded in the
logs. If your RabbitMQ installation contains important data then we
recommend you contact support@rabbitmq.com for assistance with the
upgrade.
