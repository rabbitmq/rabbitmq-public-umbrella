SPLITSPECS=amqp0-8 amqp0-9-1

all: $(SPLITSPECS)

diff: all
	colordiff -Nr -u amqp0-8 amqp0-9-1 | less

%: ../%.xml
	mzscheme -f splitspec.ss $@ < $<

clean:
	rm -rf $(SPLITSPECS)
