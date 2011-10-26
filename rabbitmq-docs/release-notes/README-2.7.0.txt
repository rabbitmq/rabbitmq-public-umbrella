Release: RabbitMQ 2.7.0

Release Highlights
==================

[*Bugs with no effect upon the release notes, remove these before release:*

* 24424	Docs/Website	Some man pages contained duplicate text.
* 23866	Docs/Website	Add navigation to next steps after server download, install
* 24403	Docs/Website	Fix doctype to prevent entity load warnings in driver.py and problems when resolving remote DTD
* 24474	Plug-ins	[CI] Leaving pid file lying around is racy
* 24514	Broker	soak tests broken due to api change from bug 24509
* 24510	Broker	make start-background-node start-rabbit-on-node breaks logging after bug 24332
* 24362	Broker	[CI] mirrored_supervisor tests fail occasionally
* 24509	Broker	new requeue code causes messages to expire too late (caused by 23764)
* 24508	Broker	replace timer:apply_interval with timer:send_interval
]

server
------

*enhancements*

- Messages requeued (as a result of a consumer dying, for example) will now
  preserve the original order.
(23764)
- There have been some changes to improve RAM utilisation under high
  load, and to reduce the time taken to parse message properties.
(17162, 17174) 
- Shutdown, when there are a large number of queues to delete, is now
  more efficient.
(24298) 
- All actions initiated by rabbitmqctl are now logged.
(24315) 
- The server can now automatically adapt to changing virtual memory resources,
  and dynamic updates to the memory high-watermark.
(24323) 
- The rabbit logs have a more conventional management pattern to enable
  log rotation to be simpler.
(24332) 
- Basic file operations are now more efficient.
(24386)
- Durable queues are now faster on first use, and faster to recover.
(24425, 24428)
- Creating a connection is now faster.
(24416)
- (24433) improve performance of many low-res consumers
- (24455) manage RAM overhead for messages already on disk
- (24459) improve performance of ack/reject handling
- (24461) make rabbit_event API more pleasant and less costly
- (23056) Code Quality: all exported Erlang functions should now have type specifications.

*bug fixes*

- Equivalent queues created by different software libraries could look different
  to the broker, causing queue creation errors.
(24481)
- (24511) VQ soak test must generate unique message IDs
- (24504) various tiny performance tweaks
- (23596) revise channel queue monitoring to avoid unnecessary monitors
- (24371) test startup checks improved and made consistent
- (24460) tx.rollback can break multi-ack
- (24462) x-ha-policy = nodes does not work
- (24477) msg_store erroneously confirms messages on 'remove'
- (24478) (Windows) WCF tests fail due to PID mismatch under cygwin
- (24483) (Windows) escape backslashes in paths in BAT files
- (24486) 'badarg' error when displaying plug-in activation error


build and packaging
-------------------

*bug fixes*

- On non-Windows platforms invoking rabbitmq as a daemon can leave standard
input and output streams permanently open.
(24516)

clients
-------

*enhancements*

- There is a new "amqp" URI scheme, which can provide all of the
  information required to connect to an AMQP server in one URI.
  The Java client, the Erlang client and the .NET client all support
  this URI scheme on connect.
  See the [AMQP URI](http://www.rabbitmq.com/uri-spec.html) specification for
  more information.
(24453)

*bug fixes*

- Connection and Channel closes in the clients have internal timeouts which
  can expire prematurely and spoil the client's view of the channel state.
(24443)

erlang client
-------------

*enhancements*

- It is now possible to specify a connection timeout value on Erlang client
connections.
(24488)

*bug fixes*

- Under some circumstances wait\_for\_confirms can fail to return.
(24499)

java client
-----------

*enhancements*

- Consumer callbacks, and channel operations are now threadsafe. This means that
  calls to channel operations (even close) can be safely made from a Consumer
  method call.  There is now less need for QueueingConsumer, and Consumer clients
  can be more simply written.  Consumer callbacks are executed on a ThreadExecutor
  pool, which can be user-supplied.
(18384)
- Channel or Connection errors that refer to another frame now provide the
  frame's AMQP name (if it has one) in the error message.
(24391)

plugins
-------

*enhancements*

- There is a new rabbitmq-plugins tool to enable and disable plugins.
  Plugins are now included in the main rabbitmq-server release,
  simplifying server configuration and plugin installation and upgrades.
(21319)
- rabbitmq_federation is now a maintained plugin.

(See [the plugins page](http://www.rabbitmq.com/plugins.html) for more information.)

*bug fixes*

- (23369) Shutdown of web-based plugins does not remove all relevant resources.

management plugin
-----------------

*enhancements*

- (24432) more detailed global memory stats

*bug fixes*

- (24423) jQuery bug makes queue details fail with HA on Firefox 6
- (24466) "all configuration" is poorly named

.net client
-----------

*bug fixes*

- (24335) user-id breaks .net message patterns

mochiweb plugin
---------------

*bug fixes*

- Increase the limit on message body size from 1MB to 100MB, so that, for example,
  JSON-RPC channel can publish much larger messages.
(24448)

- rabbitmq-mochiweb does not provide any means to unregister a context
(23235)

STOMP adapter
-------------

*bug fixes*

- (24426) The STOMP adapter can fail prematurely (instead of throttling the
  sender) when sending large numbers of messages which exceed memory limits.


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
