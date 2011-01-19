Release: RabbitMQ 2.3.0

Release Highlights
==================

server
------
bug fixes
- fix issue with message store deleting open files on Windows
- SASL PLAIN parser made more robust
- reduced likelihood of race conditions in user-supplied exchange
  implementations
- fixes for Solaris 10
- various other bug fixes

enhancements
- add confirm mode - an extension to the AMQP 0-9-1 spec allowing
  clients to receive streaming receipt confirmations for the messages
  they publish. See
  http://www.rabbitmq.com/extensions.html#confirms for more information.
- allow node name to be specified without a host
- improved diagnostic error messages in common startup error cases
- add a basic.nack method. See
  http://www.rabbitmq.com/extensions.html#negative-acknowledgements
- add an unforgeable user-id header. See
  http://www.rabbitmq.com/extensions.html#validated-user-id
- support for pluggable SASL authentication mechanisms, and a new plugin
  to authenticate using SSL (see below)
- support for authentication / authorisation backends, and a new plugin
  to authenticate and authorise using LDAP (see below)
- support for internal exchanges (cannot be published to directly,
  typically used in exchange-to-exchange bindings)


java client
-----------


.net client
-----------


management plugin
-----------------


STOMP plugin
------------


build and packaging
-------------------


ssl authentication mechanism plugin
-----------------------------------



ldap authentication backend plugin
----------------------------------



Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a non-clustered RabbitMQ from release 2.1.0, first upgrade
to 2.1.1 (which retains all data), and then to the current version as
described above.

To upgrade a clustered RabbitMQ or from releases prior to 2.1.0, if
the RabbitMQ installation does not contain any important data then
simply install the new version. RabbitMQ will move the existing data
to a backup location before creating a fresh, empty database. A
warning is recorded in the logs. If your RabbitMQ installation
contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.
