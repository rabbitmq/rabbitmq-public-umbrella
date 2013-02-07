all: amqp0-9-1.stripped.xml amqp0-9.stripped.xml amqp0-8.stripped.xml qpid-amqp.0-8.stripped.xml

%.stripped.xml: %.xml spec-stripper.xsl
	xsltproc spec-stripper.xsl $< > $@

clean:
	rm -f *.stripped.xml
