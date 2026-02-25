<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mdb="http://standards.iso.org/iso/19115/-3/mdb/2.0"
    xmlns:mcc="http://standards.iso.org/iso/19115/-3/mcc/1.0"
    xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:dct="http://purl.org/dc/terms/"
    exclude-result-prefixes="#all">
    
    <xsl:import href="../../convert/toDDE_20240204.xsl"/>
    
    <xsl:output method="xml" indent="yes" version="1.0" encoding="UTF-8" standalone="yes"/>
    
    <xsl:template match="/"   priority="2">
        <xsl:apply-templates  
            select="root/mdb:MD_Metadata | mdb:MD_Metadata"/>
    </xsl:template>
    
</xsl:stylesheet>
