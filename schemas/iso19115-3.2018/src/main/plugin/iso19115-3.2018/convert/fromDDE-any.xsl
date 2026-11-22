<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">

    <!-- Last change to this stylesheet, reported in a record's provenance so that
         output can be traced to the transformation that produced it. Bump it in the
         same commit that changes this file: StylesheetVersionTest fails when it
         falls behind the file's last commit date. -->
    <xsl:variable name="stylesheetUpdated" select="'2026-11-22'"/>
    
    <xsl:import href="utilityDDE/fromISO19115-3.2014DDE.xsl"/>
    <xsl:import href="fromDDE-20240405.xsl"/>
    <xsl:import href="fromISO19139-DDE.xsl"/>
    
</xsl:stylesheet>