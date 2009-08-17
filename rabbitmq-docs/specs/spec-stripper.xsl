<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" />

  <xsl:template match="amqp/@comment" />
  <xsl:template match="@label" />
  <xsl:template match="doc" />
  <xsl:template match="rule" />
  <xsl:template match="text()" />

  <!-- ############################################################ -->

  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>
    
  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
