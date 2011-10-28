RabbitMQ 2.7.0
==============
Release Highlights
==================

server
------
*enhancements*

- Messages requeued (as a result of a consumer dying, for example) have their
  original order preserved.
- The server automatically adapts to changes to virtual memory resources, and
  to the memory high-watermark.
- The rabbit logs are appended to on restart; log rotation is simplified.
- Non-query actions initiated by rabbitmqctl are logged.
- Creating a connection is faster.
- RAM utilisation under high load is improved, and the time taken to parse
  message properties is reduced.
- Shutdown is more efficient, especially when there are many queues to delete.
- Concurrent message storage operations for many queues are more efficient.
- Durable queues are faster on first use, and faster to recover.
- Performance improvements to: exchange, consumer and acknowledgement
  management.

*bug fixes*

- Acknowledgements were not properly handled on transaction rollback.
- Could not declare a mirrored queue with a policy of "nodes" and an explicit
  list of node names.
- Queues created by different software libraries could look inequivalent
  to the broker, though they had equivalent properties.
- In large queues under load, messages already on disk were retained in memory
  for too long.
- Queue process monitors were not removed correctly.
- (Windows) Some batch file variables might pass unescaped backslashes to the
  broker, causing it to crash.

clients
-------
*enhancement*

- Clients accept a new "amqp" URI scheme, which can describe all of the
  information required to connect to an AMQP server in one URI.

  (See the [AMQP URI](http://www.rabbitmq.com/uri-spec.html) page for
  more information.)

*bug fix*

- Connection and Channel closes in the clients had internal timeouts which
  could expire prematurely and spoil the client's view of the channel state.

erlang client
-------------
*enhancement*

- A connection timeout value is accepted on Erlang client connections.

*bug fix*

- Under some circumstances wait_for_confirms/1 could fail to return.

java client
-----------
*enhancements*

- Consumer callbacks, and channel operations are threadsafe. Calls to channel
  operations can be safely made from a Consumer method call.  Consumer callback
  work threads can be user-supplied.
- Channel or Connection errors that refer to another method frame provide the
  method's AMQP name (if it has one) in the error message.

plugins
-------
*enhancements*

- Plugins are included in the main rabbitmq-server release, simplifying server
  configuration and plugin installation and upgrades. The new rabbitmq-plugins
  tool enables and disables plugins.
- rabbitmq_federation is no longer experimental and is now a maintained plugin.
  rabbitmq_tracing and rabbitmq_consistent_hash_exchange are two new
  experimental plugins.
  
  (See the [plugins](http://www.rabbitmq.com/plugins.html) page for more
  information.)

*bug fix*

- Shutdown of web-based plugins did not remove mochiweb resources which
  could leave erroneous pages accessible.

management plugin
-----------------
*enhancements*

- There are more, and more detailed, global memory statistics shown.
- In Dump and restore, "all configuration" is renamed to "Definitions".

*bug fix*

- HA queue details failed to display on some browsers.

mochiweb plugin
---------------
*enhancement*

- The limit on message body size is increased to 100MB, so that, for example,
  JSON-RPC channel can publish much larger messages.

STOMP adapter
-------------
*bug fix*

- The STOMP adapter could crash when exceeding the memory high watermark.

build and packaging
-------------------
*bug fix*

- On non-Windows platforms invoking rabbitmq as a daemon could leave standard
  input and output streams permanently open.

Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install
the new version on all the nodes and follow these
[upgrading](http://www.rabbitmq.com/clustering.html#upgrading) instructions.

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
