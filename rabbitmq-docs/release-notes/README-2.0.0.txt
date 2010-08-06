Release: RabbitMQ 2.0.0

Release Highlights
==================

server
------
bug fixes
- fix bug that resulted in 'rabbitmqctl status' reporting disk nodes
  as ram nodes
- tx.commit no longer fails when participating queues are deleted
  during the lifetime of the transaction

enhancements
------------
- new persister - see #link to yet-to-be-written blog post
  - the volume of messages rabbit can hold on to is bounded by disk
    space (in previous versions it was bounded by memory)
  - rabbit optimises memory usage by paging messages out to / in from
    disk as needed
  - consistently high performance regardless of retained message
    volume (previous versions would slow down considerably as the
    persisted message volume grew)
  - consistently fast startup regardless of volume of persisted data
    (previous versions would require time proportional to the amount
    of data)
  - better performance for concurrent transactions (in previous
    version the rate at which queues could handle transactions
    involving persistent messages was fixed)
- implement AMQP 0-9-1, in addition to 0-8 - see
  http://www.rabbitmq.com/specification.html
- instrumentation for asynchronous statistics events, emitting more
  stats than currently available and laying the foundation for
  monitoring a busy broker w/o significantly impacting performance -
  see #link to yet-to-be-written blog post
- more effective flow control mechanism that does not require
  cooperation from clients and reacts quickly to prevent the broker
  from exhausing memory - see
  http://localhost:8191/extensions.html#memsup
- implement basic.reject - see
http://www.rabbitmq.com/blog/2010/08/03/well-ill-let-you-go-basicreject-in-rabbitmq/
- introduce support for queue leases - see http://www.rabbitmq.com/extensions.html#queue-leases
- improve the setting of permissions, making it easer to use and
  introducing a way to grant no permissions at all - see http://www.rabbitmq.com/admin-guide.html#management
- delete exclusive queues synchronously on server-initiated connection
  close (rather than just client-initiated)


java client
-----------
enhancements
- switch to AMQP 0-9-1 - see
  http://www.rabbitmq.com/specification.html


.net client
-----------
bug fixes
- fix bug that caused incorrect responses to server-issued
  channel.flow commands, which in turn resulted in connections getting
  closed with an error.

enhancements
- implement AMQP 0-9-1, in addition to 0-8 and 0-9 - see
  http://www.rabbitmq.com/specification.html
- simplify the Subscription class and make it more versatile
- improve documentation


building & packaging
--------------------
bug fixes
- correct location of rabbitmq.config file under macports - it now
  lives in /opt/local/etc/rabbitmq/

enhancements
- portable, binary plug-in releases to simplify plug-in installation -
  see http://www.rabbitmq.com/plugins.html


Upgrading
=========
The database schema and the format in which persistent messages are
stored have both changed since the last release (1.8.1). When
starting, the RabbitMQ server will detect the existence of an old
database and will move it to a backup location, before creating a
fresh, empty database, and will log a warning. If your RabbitMQ
installation contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.
