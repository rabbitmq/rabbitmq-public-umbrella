Release: RabbitMQ 2.1.1

Release Highlights
==================

server
------
enhancements
 - added 'client_flow' channel info item for rabbitmqctl
 - added SSL information for rabbitmqctl list_connections
 - better memory detection on AIX
 - faster connection termination for connections that use exclusive queues
 - optimized disk use when creating and deleting queues
 - added version number when backing up database - for future upgrades
 
bug fixes
 - call priority is now determined via gen_server2 behaviour callback
 - queue leases are now extended on declare as well, to prevent expiry between
a passive declare and a consume
 - fixed a bug which was causing unnecessary high disk use when writing and
removing messages to/from the message store
 - fixed high memory use due to persister
 - newly created connections emit stats immediately
 - fixed SSL RC4 cipher
 - fixed a bug related to calling Queue.Purge when there are pending acks

.net client
-----------
enhancements
 - added a way to determine if Channel.Flow is active or not

building & packaging
--------------------
enhancements
 - detection of unresolved references in code
 - building the server does not require Erlang OTP's sources any more

bug fixes
 - better use of Dialyzer: report more warnings
 - do not rebuild all .beam files if deps.mk changes
 - refined the inclusion of deps.mk in server's makefile



Upgrading
=========
The database schema has not changed since version 2.1.0, so user accounts,
durable exchanges and queues, and persistent messages will all be retained
during the upgrade.

If, however, you are upgrading from a release prior to 2.1.0, when the
RabbitMQ server detects the presence of an old database, it moves it to a
backup location, creates a fresh, empty database, and logs a warning. If
your RabbitMQ installation contains important data then we recommend you
contact support@rabbitmq.com for assistance with the upgrade.

