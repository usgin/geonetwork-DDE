#!/usr/bin/env python3
"""Check cdif-DDE-metadata-mapping.md's claims against the two converters.

The mapping document's third table column asserts what the harvester does with
each property. Those assertions drifted from the code -- two reviews in
November 2026 found rows claiming behaviour the XSLTs did not have, including a
live data-loss bug in schema:variableMeasured that nobody had noticed because
nothing checked. This is the check.

A row claiming "Mapped" is verified in both directions. The two converters spell
property names differently, which is the whole reason a grep by hand is
unreliable:

  inbound  (fromJsonCdif.xsl)        reads the framed JSON converted to XML, so
                                     a colon becomes an underscore: schema_name
  outbound (iso19115-3-to-cdif.xsl)  writes JSON text, so the name appears
                                     quoted with its colon: "schema:name"

Rows claiming "NOT mapped" are not checked -- the document is describing a gap,
and a name appearing there is usually the CDIF property that does not exist.

A capitalised local name is a class, not a property, and is treated separately.
The document writes paths like schema:temporalCoverage/time:ProperInterval/
time:hasBeginning, but in the framed JSON the class is @type on the node rather
than an element, so the inbound converter keys off the leaf properties and never
needs to name the wrapper -- it tests @type in exactly one place, for
schema:Person. Demanding a class inbound would therefore report noise, so a
class counts as an error only when neither converter knows it at all.

Usage: python tools/check_mapping_doc.py [doc.md]
Exit status 1 if any "Mapped" claim is unsupported.
"""
import io
import re
import sys

PLUGIN = "schemas/iso19115-3.2018/src/main/plugin/iso19115-3.2018/"
INBOUND = PLUGIN + "convert/fromJsonCdif.xsl"
OUTBOUND = PLUGIN + "formatter/cdif/iso19115-3-to-cdif.xsl"

# Prefixes CDIF uses. A token with no prefix (subjectOf, geo, box) is a path
# fragment inside a larger property and is not separately greppable.
PREFIX = r"(?:schema|dcterms|dct|prov|time|dqv|cdi|spdx|owl|rdfs|skos)"
TOKEN = re.compile(r"\b(%s):([A-Za-z][A-Za-z0-9]*)" % PREFIX)

RANK = {"none": 0, "partial": 1, "mapped": 2}


def rows(md):
    """Yield (cdif_column, status_column) for every mapping-table data row."""
    in_table = False
    for line in md.split("\n"):
        if not line.startswith("|"):
            in_table = False
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 3:
            in_table = False
            continue
        if cells[2] == "Harvester Status":
            in_table = True
            continue
        if set("".join(cells)) <= set("- "):
            continue
        if in_table:
            yield cells[1], cells[2]


def claim(status):
    """mapped | partial | none -- what the status column asserts."""
    low = status.lower().lstrip("(")
    if low.startswith("not mapped"):
        return "none"
    if "partially mapped" in low or low.startswith("partial"):
        return "partial"
    if "mapped" in low:
        return "mapped"
    return "none"


def main():
    doc = sys.argv[1] if len(sys.argv) > 1 else "cdif-DDE-metadata-mapping.md"
    md = io.open(doc, encoding="utf-8").read()
    inbound = io.open(INBOUND, encoding="utf-8").read()
    outbound = io.open(OUTBOUND, encoding="utf-8").read()

    # name -> strongest claim made about it anywhere in the document
    claims = {}
    for cdif, status in rows(md):
        level = claim(status)
        for prefix, name in TOKEN.findall(cdif):
            key = "%s:%s" % (prefix, name)
            if RANK[level] > RANK[claims.get(key, "none")]:
                claims[key] = level

    prop_total = 0
    prop_missing = []
    class_missing = []
    partial_gaps = []

    for key in sorted(claims):
        prefix, name = key.split(":")
        is_class = name[0].isupper()
        has_in = ("%s_%s" % (prefix, name)) in inbound
        if is_class:
            has_in = has_in or ("'%s'" % key) in inbound
        has_out = ('"%s"' % key) in outbound

        if claims[key] == "mapped":
            if is_class:
                if not (has_in or has_out):
                    class_missing.append(key)
            else:
                prop_total += 1
                if not (has_in and has_out):
                    prop_missing.append((key, has_in, has_out))
        elif claims[key] == "partial" and not (has_in or has_out):
            partial_gaps.append(key)

    print("properties the document claims are Mapped : %d" % prop_total)
    print("of those, absent from one or both XSLTs   : %d" % len(prop_missing))
    for key, has_in, has_out in prop_missing:
        where = [w for w, ok in (("inbound", has_in), ("outbound", has_out)) if not ok]
        print("  %-32s not found in %s" % (key, " and ".join(where)))

    if class_missing:
        print("\nclasses claimed Mapped, found in neither XSLT:")
        for key in class_missing:
            print("  %s" % key)

    if partial_gaps:
        print("\nclaimed Partially mapped, found in neither XSLT:")
        print("  (expected where the document is describing a CDIF gap)")
        for key in partial_gaps:
            print("  %s" % key)

    return 1 if (prop_missing or class_missing) else 0


if __name__ == "__main__":
    sys.exit(main())
