Release: RabbitMQ 2.8.6

Release Highlights
==================

server
------
bug fixes
- removing RAM nodes from a cluster no longer leads to inconsistent state
  on disk nodes (which previously failed to notice the RAM nodes' departure) 
- reap TTL-expired messages promptly rather than after a delay of up to TTL,
  which could result in performance spikes
- correct reporting of the vm_memory_high_watermark

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
