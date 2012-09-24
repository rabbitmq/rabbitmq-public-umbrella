Release: RabbitMQ 2.8.7

Release Highlights
==================

         server
         ------
         bug fixes
  25112  - fix timer error that prevented slave nodes from proactively persisting acks and
           messages
  25114  - prevent hypothetical infinite loop when deleting mirrorred queue
  25117  - fix race condition that could stop mirrorred queue from sending further
           publisher acks
  25118  - fix slave synchronisation detection logic in mirrorred queues
  25119  - fix possible deadlock during broker shutdown
  25120  - fix DOS vulnerability possible by malicious SSL clients
  25144  - fix resource leak when declaring many short-lived mirrorred queues
  25158  - fix bug that prevented publisher acks when x-message-ttl was set to zero
  25154  - make log messages around disk free space more intelligible

         enhancements
  25152  - reduce unnecessary fsync operations when deleting non-durable resources


         packaging
         ---------
         bug fixes
  25113  - ensure source packages can be built without network access


         erlang client
         -------------
         bug fixes
  25116  - prevent infinite loop when connections fail immediately on startup

         enhancements
  25152  - reduce unnecessary fsync operations when deleting non-durable resources
  25157  - offer configuration flag for ipv4 / ipv6 preference


         management plugin
         -----------------
         bug fixes
  25111  - ensure management database retains information when failing over


         STOMP plugin
         ------------
         bug fixes
  25155  - fix bug that caused alarms (e.g. disk free space checking) to turn off




Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply install
the new version. All configuration and persistent message data is retained.

To upgrade a clustered RabbitMQ from release 2.1.1 or later, install the new
version on all the nodes and follow the instructions at
http://www.rabbitmq.com/clustering.html#upgrading .

To upgrade RabbitMQ from release 2.1.0, first upgrade to 2.1.1 (all data will be
retained), and then to the current version as described above.

When upgrading from RabbitMQ versions prior to 2.1.0, the existing data will be
moved to a backup location and a fresh, empty database will be created. A
warning is recorded in the logs. If your RabbitMQ installation contains
important data then we recommend you contact support at rabbitmq.com for
assistance with the upgrade.
