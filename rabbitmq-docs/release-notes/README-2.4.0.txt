Release: RabbitMQ 2.4.0

Release Highlights
==================

server
------
bug fixes
- do not report queues on down nodes as deleted
- remove the rabbitmq-multi script
- [cluster] allow non-durable queues to be re-declared if their node
  has gone down
- fix IPv6 support on Windows
- cleanup some spurious errors in logs caused by client or server
  termination
- do not ignore the RABBITMQ_LOG_BASE variable on Windows
- fix a bug causing SSL connections to die on Erlang prior to R14
  when using "rabbitmqctl list_connections" with the SSL options
- various other fixes

enhancements
- sender-selected distribution (i.e. add support for the CC and BCC
  headers).  See
    http://www.rabbitmq.com/extensions.html#sender-selected-distribution
  for more information.
- greatly speed up routing for topic exchanges
- server-side consumer cancellation notifications.  See
    http://www.rabbitmq.com/extensions.html#consumer-cancel-notify
  for more information.
- have the server present its AMQP extensions in a "capabilities"
  field in server-properties.  See
    http://www.rabbitmq.com/extensions.html#capabilities
  for more information.
- memory alarms raised on one clustered node propagate across the
  cluster, allowing the cluster to re-act better to insufficient
  memory on any of its nodes
- rename rabbitmq.conf to rabbitmq-env.conf
- expose the frame_max configuration variable
- expose TCP configuration options.  See rabbit.app for examples.
- make rabbitmqctl give clearer errors
- improve performance for publisher confirms by increasing the
  message store timeout; note that this may degrade tx performance in
  certain cases
- various other performance improvements
- empty database files are deleted on startup
- allow SASL mechanisms to veto themselves based on socket type
- specify runlevels in the rabbitmq-server.init script
- better logging for connections refused by the server
- more useful database errors when the schema check fails


java client
-----------
bug fixes
- rename ReturnListener.handleBasicReturn to handleReturn

enhancements
- support for server-side consumer cancellation notifications
- have the client present its AMQP extensions in a "capabilities"
  field in client-properties
- make the client jar an OSGi bundle
- implement a non-recursive IntAlocater, improving behaviour for a
  larger number of channels
- ConnectionFactory accepts a connection timeout parameter
- allow prioritization of SASL mechanisms

.net client
-----------
enhancements
- support for server-side consumer cancellation notifications
- have the client present its AMQP extensions in a "capabilities"
  field in client-properties
- support for IPv6


management plugin
-----------------
bug fixes
- hide passwords in the web UI
- fix rabbitmqadmin's handling of Unicode strings

enhancements
- allow users to choose which node a queue is declared on
- present the managed socket and open file counts and respective limits
- show memory alarm states for nodes
- show statistics for basic.returns
- better memory usage reporting for hibernating queues
- implement publish/receive messages via HTTP; this is intended for
  testing / learning / debugging, not as a general solution for HTTP messaging
- better support for serving the web interface through a proxy


STOMP plugin
------------
bug fixes
- do not crash when publishing from STOMP, but subscribing from
  non-STOMP
- do not crash when publishing with undefined headers
- do not crash when publishing messages with bodies spanning packets
- receipts for SEND frames wait on confirms
- do not issue a DISCONNECT with receipt when a clean shutdown has
  *not* occurred

enhancements
- add documentation.  See
  http://www.rabbitmq.com/stomp.html
- support for multiple NACK
- support for the "persistent" header
- various performance improvements
- extend flow-control on back pressure through the STOMP gateway
  preventing the STOMP from overloading the server


SSL authentication mechanism plugin
-----------------------------------

enhancements
- only offer this mechanism on SSL connections


build and packaging
-------------------
enhancements
- Windows installer
- add the "cond-restart" and "try-restart" options to the init script



Upgrading
=========
To upgrade a non-clustered RabbitMQ from release 2.1.1 or later, simply
install the new version. All configuration and persistent message data
is retained.

To upgrade a non-clustered RabbitMQ from release 2.1.0, first upgrade
to 2.1.1 (which retains all data), and then to the current version as
described above.

To upgrade a clustered RabbitMQ or from releases prior to 2.1.0, if
the RabbitMQ installation does not contain any important data then
simply install the new version. RabbitMQ will move the existing data
to a backup location before creating a fresh, empty database. A
warning is recorded in the logs. If your RabbitMQ installation
contains important data then we recommend you contact
support@rabbitmq.com for assistance with the upgrade.
