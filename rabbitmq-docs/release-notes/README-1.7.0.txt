broker:

ssl support
plugin mechanism
proper erlang config file

rabbitmqctl urlencodes the output of every command 
increase consumer throughput under high load 
maybe get channels to handle memory alarms at higher prio
rabbitmqctl can time out when rabbit is busy 
load avg calculation can fail under heavy load
On writer death due to client disconnection, resultant formatting of error msg takes GBs of memory
Cuter banner 
Binary backoff in queue hibernation 
Broker should have hooks all over the place 
POD formatting
improve performance of channel and connection termination
remove channel closing timeout since it can result in a protocol violation
display some diagnostics when rabbitmqctl fails with a badrpc error, making it easier to track down the cause
rabbitmqctl list_connections displays the connection state by default, and no longer shows absent usernames as 'none', thus avoiding possible confusion
display location of application descriptor on startup, which makes it easy to locate rabbit installations
graceful handling of some rare error conditions during connection establishment


building & packaging
packages should store binaries and headers in the non-off...
Update windows bundle from R11B5 to R12Bsomething or later 
include .net client in complete windows bundle

make installation work under MacPorts 1.8.0
Purging the package fails because epmd is still running 
rabbitmq-server RPM disables init script from all runlevels
make rabbitmq-server buildable under freebsd 
make startup log locations configurable in /etc/default/rabbitmq
don't stomp on RABBITMQ_* environment variables in server Makefile
fix some escaping/quoting corner cases in wrapper scripts


.net
Dot Net client installer for Windows 
Default heartbeat timeout should be 0 (i.e. off)
switch from nant to msbuild, and add VS solution

SharedQueue should allow draining after close
properties should implement ICloneable 
Subscription shutdown brain damaged 
add some AmqpTcpEndpoint constructors 


Java
Default heartbeat timeout should be 0 (i.e. off)

Channel number allocation afflicted by Hotspot 
deep clone of content properties 
channel.queuePurge missing 
Make BasicProperties cloneable 


Erlang
first official release
