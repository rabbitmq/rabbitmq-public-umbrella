Release: RabbitMQ 2.2.0

Release Highlights
==================

server
------
bug fixes
 - clustering reset no longer destroys installed plugins
 - fix race condition between queue declaration and connection termination
 - fix memory leak when channel consume on many queues but do not close
 - fix issue with backing queue where changes to the queue index state are lost

enhancements
 - automatic, lossless upgrade of queue and message state
 - support per-queue message TTL. See:
   http://www.rabbitmq.com/extensions.html#queue-ttl
 - store passwords as hashes
 - allow server properties to be configured in the RabbitMQ config file
 - SSL connections are listed as such by rabbitmqctl

java client
-----------
enhancements
 - 'noAck' argument renamed to 'autoAck'
 - add PossibleAuthenticationFailureException and
 ProtocolVersionMismatchException to match up with the .net client.

.net client
-----------
bug fixes
 - fix race condition during connection.close

management plugin
-----------
bug fixes
 - fix issue preventing user authentication when using Safari
 - backing queue stats now display correctly

enhancements
 - the management plugin is now fully cluster-aware

STOMP plugin
----------
enhancements
 - Overhaul the destination selection process to use only the
 'destination' header
 - Add support for /queue and /topic destinations
 - Remove support for custom 'routing_key' and 'exchange headers' and
 introduce /exchange/<name>/<key> destination type
 - The order of SEND and SUBSCRIBE frames is no longer important
 - STOMP connections show up as such in the management plugin

Upgrading
=========
The database schema has changed since the last release
(2.1.1). However, with the introduction of the new lossless upgrade
feature, RabbitMQ will upgrade your database to the new schema format automatically.
