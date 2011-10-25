Release: RabbitMQ 2.7.0

Release Highlights
==================

server
------
bug fixes
-(23596) revise channel queue monitoring to avoid unnecessary monitors
-(23764) preserve order of requeued messages for single consumer
-(23866, 24403, 24424) man pages corrections
-(24371) test startup checks improved and made consistent
-(24460)NR tx.rollback can break multi-ack
-(24462)NR x-ha-policy = nodes does not work
-(24477) msg_store erroneously confirms messages on 'remove'
-(24478) (Windows) WCF tests fail due to PID mismatch under cygwin
-(24483) (Windows) escape backslashes in paths in BAT files
-(24486)NR 'badarg' error when displaying plug-in activation error

enhancements
-(17162, 17174) improve flow control and parsing performance in the broker
-(23056) type specifications on exported functions
-(24298) improve shutdown performance
-(24315) log rabbitmqctl actions
-(24323) adapt to changing virtual memory limit automatically and allow
  dynamic updates to the high-watermark
-(24332) improvement to error logging so that log rotation is easier
-(24386) improve performance of file functions (seen in many queue deletions)
-(24416, 24425, 24428) improve performance of connection establishment and durable queues'
  creation and recovery
-(24433) improve performance of many low-res consumers
-(24455) manage RAM overhead for messages already on disk
-(24459) improve performance of ack/reject handling
-(24461) make rabbit_event API more pleasant and less costly

build and packaging
-------------------
enhancements
-(21319) There is a new rabbitmq-plugins tool to enable and disable plugins. 
  Plugins are now included in the main rabbitmq-server release, 
  simplifying server configuration and plugin installation and upgrades. 
  (See http://www.rabbitmq.com/plugins.html for more information.)

all clients
-----------
enhancements
-(24453) AMQP URL support

.net client
-----------
bug fixes
-(24335) user-id breaks .net message patterns

java client
-----------
enhancements
-(18384) threadsafe channels and consumer callbacks
-(24391) show causing method name in channel/connection errors

management plugin
-----------------
bug fixes
-(24423)NR jQuery bug makes queue details fail with HA on Firefox 6
-(24466) "all configuration" is poorly named

enhancements
-(24432) More detailed global memory stats

mochiweb plugin
---------------
bug fixes
-(23235) rabbitmq-mochiweb does not provide any means to unregister a context

enhancements


23369	Plug-ins	Fix shutdown for web plugins
24448	Plug-ins	JSON-RPC channel won't publish messages > 1MB due to Mochiweb limit
24474	Plug-ins	[CI] Leaving pid file lying around is racy
24426	STOMP gateway	Crash during high message rate after memory alarm raised


STOMP plugin
------------
bug fixes

enhancements

See the STOMP plugin documentation at http://www.rabbitmq.com/stomp.html

federation plugin
-----------------


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
