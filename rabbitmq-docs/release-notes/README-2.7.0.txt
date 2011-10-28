RabbitMQ 2.7.0
==============
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
* 24504	Broker	various tiny performance tweaks
* 24511	Broker	VQ soak test must generate unique message IDs
* 24433	Broker	improve performance of many low-res consumers
* 24459	Broker	improve performance of ack/reject handling
* 24461	Broker	make rabbit_event API more pleasant and less costly
* 24371	Broker	test startup checks improved and made consistent
* 24477	Broker	msg_store erroneously confirms messages on 'remove'
* 24478	Broker	(Windows) WCF tests fail due to PID mismatch under cygwin
* 24486	Broker	'badarg' error when displaying plug-in activation error
* 24335	Broker	user-id breaks .net message patterns
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
- Code Quality: more exported Erlang functions now have type specifications.
(23056)

*bug fixes*

- Equivalent queues created by different software libraries could look different
  to the broker, causing queue creation errors.
(24481)
- In large queues, messages already on disk retain memory for too long making
  memory utilisation unnecessarily high under load.
(24455)
- Queue process monitors are not removed correctly, which is a resource leak.
(23596)
- Acknowledgements are not properly handled on transaction rollback.
(24460)
- Cannot declare a mirrored queue with a policy of "nodes" and an explicit
  list of node names.
(24462)
- (Windows) Some batch file variables may pass unescaped backslashes to the
  broker, causing it to crash.
(24483)

build and packaging
-------------------
*bug fixes*

- On non-Windows platforms invoking rabbitmq as a daemon can leave standard
  input and output streams permanently open.
(24516)

clients
-------
*enhancements*

- There is a new "amqp" URI scheme, which can describe all of the
  information required to connect to an AMQP server in one URI.
  The Java client, the Erlang client and the .NET client all support
  this URI scheme on connect.
  See the [AMQP URI](http://www.rabbitmq.com/uri-spec.html) page for
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

- Under some circumstances wait\_for\_confirms/1 can fail to return.
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

- Shutdown of web-based plugins does not remove all relevant mochiweb resources
  which may mean that listeners do not terminate when they should.
(23369)

management plugin
-----------------
*enhancements*

- There are more, and more detailed, global memory statistics shown.
(24432)

*bug fixes*

- HA queue details fail to display on some browsers.
(24423)
- Dump and restore of "all configuration" is poorly named. ('Definitions' is
  used instead.)
(24466)

mochiweb plugin
---------------
*bug fixes*

- Increase the limit on message body size from 1MB to 100MB, so that, for example,
  JSON-RPC channel can publish much larger messages.
(24448)

- rabbitmq-mochiweb does not provide any means to unregister a context.
(23235)

STOMP adapter
-------------
*bug fixes*

- The STOMP adapter can fail prematurely (instead of slowing the sender)
  when sending large numbers of messages and exceeding the memory high
  watermark.
(24426) 

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

Upgrades from RabbitMQ versions prior to 2.1.0 or a stand-alone broker
from releases prior to 2.1.0, if the RabbitMQ installation does not
contain any important data then simply install the new
version. RabbitMQ will move the existing data to a backup location
before creating a fresh, empty database. A warning is recorded in the
logs. If your RabbitMQ installation contains important data then we
recommend you contact support@rabbitmq.com for assistance with the
upgrade.
