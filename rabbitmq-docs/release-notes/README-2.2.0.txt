Release: RabbitMQ 2.2.0

Release Highlights
==================

server
------
enhancements
 - automatic, lossless upgrade of queue and message state
 - support for per-queue message TTL. See:
   http://www.rabbitmq.com/extensions.html#queue-ttl
 - store passwords as hashes
 - server properties can now be configured in the RabbitMQ config
  file
 - SSL connections are now listed as such by rabbitmqctl

bug fixes
 - clustering reset no longer destroys installed plugins
 - fixed race condition between queue declaration and connection
  termination
 - fixed potential leak of channel state
 - fixed index state loss in variable queue

java client
-----------
enhancements
 - 'noAck' argument renamed to 'autoAck'
 - added PossibleAuthenticationFailureException and
 ProtocolVersionMismatchException to match up with the .net client.

.net client
-----------
bug fixes
 - fixed race condition during connection.close

management plugin
-----------
enhancements
 - the management plugin is now fully cluster-aware

bug fixes
 - fixed authentication is Safari
 - backing queue stats now display correctly

STOMP plugin
----------
enhancements
 - Overhauled the destination selection process to use only the
 'destination' header
 - Added support for /queue and /topic destinations
 - Removed support for custom 'routing_key' and 'exchange headers' and
 introduced /exchange/<name>/<key> destination type
 - The order of SEND and SUBSCRIBE frames is no longer important
 - STOMP connections show up as such in the management plugin

Upgrading
=========
The database schema has changed since the last release
(2.1.1). However, with the introduction of the new lossless upgrade
feature, RabbitMQ will upgrade your database to the new schema format automatically.
