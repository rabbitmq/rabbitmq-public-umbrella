Release: RabbitMQ 2.7.0

Release Highlights
==================

server
------
bug fixes
- acknowledgements were not properly handled on transaction rollback.
- could not declare a mirrored queue with a policy of "nodes" and an explicit
  list of node names.
- queues created by different software libraries could look inequivalent
  to the broker, though they had equivalent properties.
- in large queues under load, messages already on disk were retained in memory
  for too long.
- queue process monitors were not removed correctly.
- (Windows) some batch file variables might pass unescaped backslashes to the
  broker, causing it to crash.

enhancements
- messages requeued (as a result of a consumer dying, for example) have their
  original order preserved.
- the server automatically adapts to changes to virtual memory resources, and
  to the memory high-watermark.
- the rabbit logs are appended to on restart; log rotation is simplified.
- non-query actions initiated by rabbitmqctl are logged.
- creating a connection is faster.
- RAM utilisation under high load is improved, and the time taken to parse
  message properties is reduced.
- shutdown is more efficient, especially when there are many queues to delete.
- concurrent message storage operations for many queues are more efficient.
- durable queues are faster on first use, and faster to recover.
- performance improvements to: exchange, consumer and acknowledgement
  management.

clients
-------
bug fixes
- connection and channel closes in the clients had internal timeouts which
  could expire prematurely and spoil the client's view of the channel state.

enhancements
- clients accept a new "amqp" URI scheme, which can describe all of the
  information required to connect to an AMQP server in one URI.

  See http://www.rabbitmq.com/uri-spec.html for more information.

erlang client
-------------
bug fixes
- under some circumstances wait_for_confirms/1 could fail to return.

enhancements
- a connection timeout value is accepted on Erlang client connections.

java client
-----------
enhancements
- consumer callbacks, and channel operations are threadsafe. Calls to channel
  operations can be safely made from a Consumer method call.  Consumer callback
  work threads can be user-supplied.
- channel or connection errors that refer to another method frame provide the
  method's AMQP name (if it has one) in the error message.

plugins
-------
bug fixes
- shutdown of web-based plugins did not remove mochiweb resources which
  could leave erroneous pages accessible.

enhancements
- plugins are included in the main rabbitmq-server release, simplifying server
  configuration and plugin installation and upgrades. The new rabbitmq-plugins
  tool enables and disables plugins.
- rabbitmq_federation is no longer experimental and is now a maintained plugin.
  rabbitmq_tracing and rabbitmq_consistent_hash_exchange are two new
  experimental plugins.

  See http://www.rabbitmq.com/plugins.html for more information.

management plugin
-----------------
bug fixes
- HA queue details failed to display on some browsers.

enhancements
- there are more, and more detailed, global memory statistics shown.
- in dump and restore, "all configuration" is renamed to "Definitions".

mochiweb plugin
---------------
enhancements
- the limit on message body size is increased to 100MB, so that, for example,
  JSON-RPC channel can publish much larger messages.

STOMP adapter
-------------
bug fixes
- the STOMP adapter could crash when exceeding the memory high watermark.

build and packaging
-------------------
bug fixes
- on non-Windows platforms invoking rabbitmq as a daemon could leave standard
  input and output streams permanently open.

Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install
the new version on all the nodes and follow these
[upgrading](http://www.rabbitmq.com/clustering.html#upgrading) instructions.

To upgrade RabbitMQ from release 2.1.0, first upgrade to 2.1.1 (which
retains all data), and then to the current version as described above.

When upgrading from RabbitMQ versions prior to 2.1.0, the existing
data will be moved to a backup location and a fresh, empty database
will be created. A warning is recorded in the logs. If your RabbitMQ
installation contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.
