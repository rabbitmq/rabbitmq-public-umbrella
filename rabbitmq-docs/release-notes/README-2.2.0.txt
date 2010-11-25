Release: RabbitMQ 2.2.0

Release Highlights
==================

server
------
bug fixes
- fix issue that causes cross-cluster communication to deadlock after
  sustained cluster activity
- fix queue memory leak when using the management plugin or other
  consumers of queue statistics
- brokers started with rabbitmq_multi.bat are now restartable
- clustering reset no longer destroys installed plugins
- fix race condition between queue declaration and connection
  termination that causes spurious noproc errors to appear in the log
- fix memory leak when long-running channels consume and cancel on
  many queues
- queue.declare and exchange.declare raise precondition_failed rather
  than not_allowed when attempting to redeclare a queue or exchange
  with parameters different than those currently known to the broker

enhancements
- automatic, lossless upgrade to new versions of RabbitMQ
  (when not clustered)
- support per-queue message TTL. See:
  http://www.rabbitmq.com/extensions.html#queue-ttl
- the volume of pending acks is now bounded by disk space rather
  than by memory
- store passwords as hashes
- allow server properties to be configured in the RabbitMQ config file
- SSL connections are listed as such by rabbitmqctl
- simplify permission configuration by removing the client
  permission scope
- improve performance of message routing
- removed support for basic.recover with requeue=false

java client
-----------
enhancements
- 'noAck' argument renamed to 'autoAck'
- add PossibleAuthenticationFailureException and
  ProtocolVersionMismatchException to match up with the .net client.

.net client
-----------
bug fixes
- fix race condition that can cause spurious SocketErrors to be thrown
  during connection.close
- fix WCF support to use 'amq.direct' exchange instead of default
  exchange

management plugin
-----------------
bug fixes
- fix issue preventing user authentication when using Safari
- backing queue stats now display correctly

enhancements
- the management plugin is now fully cluster-aware
- show detailed incoming/outgoing message rates per channel, exchange
  and queue
- show active/idle state for channels and queues
- show node uptime, rabbit version, erlang version and total queued
  messages
- add tab completion to rabbitmqadmin

STOMP plugin
------------
enhancements
- overhaul the destination selection process to use only the
  'destination' header
- add support for /queue and /topic destinations
- remove support for custom 'routing_key' and 'exchange headers' and
  introduce /exchange/<name>/<key> destination type
- the order of SEND and SUBSCRIBE frames is no longer important
- STOMP listeners show up as such in the management plugin

build and packaging
-------------------
bug fixes
- remove build-time dependency on OTP source to allow users to
  build without the OTP source present
- eliminate all valid dialyzer errors

enhancements
- include pre-compiled man pages in the MacPorts distribution,
  drastically reducing the number of dependencies required.

Upgrading
=========
The database schema has changed since the last release (2.1.1). However,
with the introduction of the new lossless upgrade feature, RabbitMQ will
upgrade databases from 2.1.1 to the new schema format automatically.

Upgrade for nodes in a cluster is not supported.

Note also that upgrade directly from 2.1.0 to 2.2.0 is not supported;
in order to perform such an upgrade while retaining the database,
you will need to upgrade first from 2.1.0 to 2.1.1, and then from
2.1.1 to 2.2.0.

There is no support in the broker for upgrading from releases prior
to 2.1.0 while retaining database; the old database will be moved
aside when the new version of the broker starts.
