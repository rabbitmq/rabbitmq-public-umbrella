# Rabbit Public Umbrella

This repository makes it easier to work on multiple RabbitMQ sub-projects
at once. It is no longer a requirement for working on an individual plugin
(as of the 3.6.0 cycle) thanks to `erlang.mk`.


## Initial Clone

After you clone the umbrella for the first time, use

    make co

to clone all dependencies. They will be checked out under `deps`.

Dependencies (sub-projects) are named after their Erlang application
names. Mostly they are self-explanatory but there are some less obvious
cases for historical reasons:

 * `rabbit` is RabbitMQ server
 * `amqp_client` is RabbitMQ Erlang client (AMQP 0-9-1)
 * `rabbit_common` is a library shared by the above
 * `rabbitmq_test` contains Erlang tests for the server
 * `rabbitmq_java_client` also contains integration test suites for the server

## Running RabbitMQ from Source

From `deps/rabbit`:

    make run-broker

If you need to access log files, see under `$TMPDIR/rabbit*`.


## Running Tests

### Integration Tests

To run only integration tests, make sure you have JDK 7+ and `ant` installed.
Then run a broker node in one shell with

    cd deps/rabbit
    make run-broker

and run integration test suites with:

    cd deps/rabbitmq_java_client
    ant test-functional

to run all Java-based test suites (this will take some 15 minutes
on a modern MBP), use

    ant test-suite

### Unit Tests

    cd deps/rabbitmq_test
    make unit

### Full Server Tests

To run all server tests, use

    cd deps/rabbitmq_test
    make full

Note that the above can take up to 45 minutes.

### Sub-projects

To run tests for a sub-project, run

    make tests

from its directory.


## Running RabbitMQ with Plugins

To build a package, and all its dependencies, cd into the package
directory under `deps` and run `make`.

To start RabbitMQ from a plugin directory, use `make run-broker`.

To run a node with multiple plugins, cd into `deps/rabbit` (the server), and run
it with `PLUGINS` listing the plugins you need:

    make run-broker PLUGINS='rabbitmq_management rabbitmq_consistent_hash_exchange'


## Variables That Can Be Set When Building

The following variables can be passed on the 'make' command line in
order to configure builds.

 * `ERL`: the Erlang 'erl' command to use, `erl` by default

 * `ERLC`: the Erlang 'erlc' command to use, `erlc` by default

 * `TMPDIR`: temporary directory for database directories, logs, etc

 * `VERSION`, `RABBIT_VSN`: the RabbitMQ version number, `0.0.0` by default


## Packaging

The distro-specific packaging targets are now integrated into the 
top-level build system. You should need to do no more than:

    make VERSION=<Version> UNOFFICIAL_RELEASE=1 dist

to build debs and rpms, along with the source and binary tarballs. If
you just want to build one package, you can use the targets
debian_packages, rpm_packages or java_packages in the top-level
Makefile.

You need to have cdbs installed to build the Debian packages, and rpm 
for the Fedora packages.

The variable `UNOFFICIAL_RELEASE` is used to determine whether packages 
should be signed: if the variable is set then they will not be 
signed, otherwise they will be. The signing key ID is `056E8E56`.

`UNOFFICIAL_RELEASE` is also used by the Debian target to determine 
changelog behaviour. If it is not set, then debian/changelog must 
contain an entry for the version string in `<Version>`. If it is set, 
it creates a fake changelog entry.
