Release: RabbitMQ 2.8.6

Release Highlights
==================

server
------
bug fixes
- the broker no longer reaps dead messages in batches based on the TTL,
  which could lead to high latency when combined with a DLX, but instead
  the server will try to reap messages at or shortly after their
  TTL-based expiry
- removing RAM nodes from a cluster no longer leads to inconsistent state
  on disk nodes (which previously failed to notice the RAM nodes' departure) 
- the broker now handles the vm_memory_high_watermark more explicitly, tracking
  and using the supplied value directly instead of reconstructing the high
  watermark from limit/total absolute values

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
