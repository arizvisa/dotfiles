#!/bin/sh
KB=
url="http://search.microsoft.com/en-us/DownloadResults.aspx?q=($KB)"

cat >/dev/null <<XSLT
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" />
<xsl:template match="//div[@class='download_results']//a">
    <xsl:variable name="index" select="@ms.index" />
    <xsl:variable name="url" select="@href" />
    <a id="{$index}" href="{$url}"><xsl:value-of select="@ms.title"</a>
</xsl:template>
XSLT
