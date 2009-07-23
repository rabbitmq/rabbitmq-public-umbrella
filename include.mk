# This is a global include file for all Makefiles

EBIN_DIR=ebin
SOURCE_DIR=src
INCLUDE_DIR=include
DIST_DIR=dist

INCLUDES=$(wildcard $(INCLUDE_DIR)/*.hrl)
SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TARGETS=$(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam, $(SOURCES))

ERLC_OPTS=-I $(INCLUDE_DIR) -o $(EBIN_DIR) -Wall

RABBIT_SERVER=rabbitmq-server
