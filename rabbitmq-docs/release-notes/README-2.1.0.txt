Release: RabbitMQ 2.1.0

Release Highlights
==================

server
------
enhancements
 - introduce a proper process supervision tree for internal processes
 - extend permissions system - add 'is_admin' field; useful for
   the management plugin
 - clean up dead code in various places
 - print plugin versions on startup
 - update documentation for file handle cache
 - detects incorrect nodename in rabbitmq_multi
 - extend supported timeout types for queue lease, see
   http://www.rabbitmq.com/extensions.html#queue-leases
 - code responsible for bindings found a new home in a separate module
 - improved api to a bindings module

bug fixes
 - in the presence of 'verify_peer' option broker will now not accept
   self-signed ssl certificates
 - queue.declare and queue.delete should always work quickly, even
   if the broker is busy
 - fixed race condition which might result in a message being lost when
   the broker is quitting
 - fixed sasl logging to terminal
 - the 'client' permission scope wasn't working correctly
 - fixed race condition in heartbeat handling, which could result
   in a connection being dropped without logging the reason for that
 - fixed 'rabbitmq_multi stop_all' on freebsd

java client
-----------
enhancements
 - basic.consume 'filter' argument is now called 'arguments'
 - added --help flag to MulticastMain
 - dropped Channel.queuePurge/2 method

.net client
-----------
enhancements
 - basic.consume 'filter' argument is now called 'arguments'

bug fixes
 - fixed race condition in synchronous basic.recover
 - codegen was generating incorrect code for nowait parameter


Upgrading
=========
The database schema and the format in which persistent messages are
stored have both changed since the last release (2.0.0). When
starting, the RabbitMQ server will detect the existence of an old
database and will move it to a backup location, before creating a
fresh, empty database, and will log a warning. If your RabbitMQ
installation contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.

