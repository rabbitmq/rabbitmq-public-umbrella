This Umbrella project is an helper to ease the work on RabbitMQ and all
its related repositories.

This file is very important for rabbitmq-components.mk: it is used to
determine when a project was downloaded under the Umbrella. The project
then knows where to find dependencies and make sure `make distclean` is
disabled.

PLEASE DO NOT REMOVE OR RENAME THIS FILE!
