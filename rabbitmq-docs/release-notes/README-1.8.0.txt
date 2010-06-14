Release: RabbitMQ 1.8.0

Release Highlights
==================

server
------
bug fixes
- prevent a change in host name from preventing RabbitMQ from being
  restarted.
- ensure that durable exclusive queues do not survive a restart of the
  broker.
- fix a race condition that could occur when concurrently declaring
  exclusive queues.
- ensure that queues being recovered by a node in a cluster cannot be
  accessed via other nodes until the queue is fully initialised.
- prevent bursts of declarations or deletions of queues or exchanges
  from exhausting mnesia's transactional capacity.
- prevent bursts of connections from exhausting TCP backlog buffers.
- various corrections to documentation to correct discrepancies
  between the website, the man pages, and the commands' usage outputs.

enhancements
------------
- introduce a pluggable exchange type API permitting plugins to the
  broker to define new exchange types which can then be used by
  clients.
- introduce a backing queue API permitting plugins to the broker to
  define new ways in which messages can be stored.
- several semantic changes to bring the behaviour inline with the AMQP
  0-9-1 spec:
  + honour many of the queue exclusivity requirements for AMQP 0-9-1,
    such as queue redeclaration, basic.get, queue.bind and
    queue.unbind.
  + honour exchange and queue equivalence requirements for AMQP 0-9-1,
    especially for queue and exchange redeclaration.
  + ensure that exclusive queues are synchronously deleted before the
    connection fully closes.
  + permit durable queues to be bound to transient exchanges.
  + enforce detection and raising exceptions due to invalid and reused
    delivery-tags in basic.ack rigorously
  + queue.purge now does not remove unacknowledged messages.
- require clients to respond to channel.flow messages within 10
  seconds to avoid an exception being raised and more rigorously deal
  with clients that disobey channel.flow messages. See
  http://www.rabbitmq.com/extensions.html#memsup
- the server now supports the client sending channel.flow messages to
  temporarily halt the flow of deliveries to the client.
- optimise cross-node routing of messages in a cluster scenario whilst
  maintaining visibility guarantees.
- ensure that clients who present invalid credentials cannot flood the
  broker with requests.
- ensure that the minimum number of frames are used to deliver
  messages, regardless of incoming and outgoing frame sizes.
- drop support for versions of Erlang older than R12B-3.
- display the current version of Erlang when booting Rabbit, and
  ensure the version is sufficiently youthful.
- work around some name resolver issues, especially under Windows.
- introduce a Pacemaker OCF script (and then fix it, thanks to patches
  by Florian Haas) to permit RabbitMQ to be used in basic
  active/passive HA scenarios (see
  http://www.rabbitmq.com/pacemaker.html).


java client
-----------
bug fixes
- fix a race condition when closing channels which could lead to the
  same channel being closed twice.
- MulticastMain could calculate negative rates, due to integer
  wrapping.
- be consistent about naming conventions.

enhancements
- Java client is now available via Maven Central.
- redesign the ConnectionFactory to be more idiomatic.
- expose server properties in connection.start.
- allow additional client properties to be set in connection.start_ok.
- attempt to infer authentication failures and construct appropriate
  exceptions.
- MulticastMain now logs returned publishes.


.net client
-----------
bug fixes
- prevent memory leak due to DomainUnload event handler.
- improvements to catching connections which are timing out.
- ensure explicitly numbered closed channels return their channel
  number to the pool correctly.
- removed artificial limitation on maximum incoming message size.

enhancements
- expose server properties in connection.start.
- allow additional client properties to be set in connection.start_ok.
- attempt to infer authentication failures and construct appropriate
  exceptions.


code generation
---------------
enhancements
- permit multiple specifications to easily be combined and merged.
- permit any number of different "actions" in code generation.


building & packaging
--------------------
bug fixes
- stop the INSTALL file from being installed in the wrong place by the
  Debian packages.
- ensure the broker can be uninstalled and/or upgraded when plugins
  have been used.

enhancements
- source rpm (.src.rpm) packages are now available
- rpm packages are now noarch, matching the debs


Upgrading
=========
The database schema and the format in which persistent messages are
stored have both changed since the last release (1.7.2). When
starting, the RabbitMQ server will detect the existence of an old
database and will move it to a backup location, before creating a
fresh, empty database, and will log a warning. If your RabbitMQ
installation contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.
