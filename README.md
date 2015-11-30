Rabbit Public Umbrella
======================

To build a package, and all its dependencies, cd into the package
directory under `deps` and run `make`.

To start RabbitMQ from a plugin directory, use `make run-broker`.
In case of `deps/rabbit` (the server), that would run RabbitMQ without
any plugins. To include a plugin or more, use `PLUGINS:

    make run-broker PLUGINS='rabbitmq_management rabbitmq_consistent_hash_exchange'


Update sub repos
----------------------

`make up` which will update every sub repository under `deps`.
