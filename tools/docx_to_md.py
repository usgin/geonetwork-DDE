#!/usr/bin/env python3
"""Convert cdif-DDE-metadata-mapping.docx to markdown, once.

The .docx was the only form of the DDE/CDIF mapping table, which made it
undiffable, unreviewable in a pull request, and unreadable by any checker. Two
reviews in November 2026 found its claims had drifted from the XSLTs it
describes -- geologic-time rows asserting behaviour the code did not have,
a composition description naming blocks that no longer exist, three wrong
counts -- with nothing to catch any of it.

This produces the markdown that replaces it, and applies the corrections those
reviews established. Kept in the repository so the conversion is reproducible
rather than a one-off done by hand.

Usage: python tools/docx_to_md.py [in.docx] [out.md]
"""
import io
import re
import sys
import zipfile

BACKSLASH = chr(92)

BANNER = """<!-- Converted from cdif-DDE-metadata-mapping.docx on 2026-11-15 by
     tools/docx_to_md.py. THIS FILE IS THE SOURCE OF TRUTH; the .docx is kept
     only as the historical original.

     The "Harvester Status" claims are checked against the converters by
     tools/check_mapping_doc.py. Run it after changing either
     convert/fromJsonCdif.xsl or formatter/cdif/iso19115-3-to-cdif.xsl. -->

"""

# Corrections established by cdif-DDE-mapping-review-RELEASE.md and -SOURCES.md.
CORRECTIONS = [
    (
        "The CDIF Complete schema is composed from CDIFDiscovery (cdifMandatory + "
        "cdifOptional) plus extensions for archive distributions, tabular data, and "
        "data cubes.",
        "The CDIF Complete schema composes six profile modules: cdifCore, "
        "cdifDiscovery, cdifDataDescription, cdifDataStructure, cdifManifest and "
        "cdifProvenance (see cdifComplete/schema.yaml). An earlier revision of this "
        "document described it as \"CDIFDiscovery (cdifMandatory + cdifOptional)\"; "
        "neither cdifMandatory nor cdifOptional exists any more.",
    ),
    (
        "The DDE schema defines 13 complex types, 14 codelist simple types, and 2 "
        "utility simple types.",
        "The DDE schema defines 14 complex types, 14 codelist simple types, and 2 "
        "utility simple types (DateTime and NilReasonType), counted from "
        "DDEMetadataXSD_20240103.xsd.",
    ),
    (
        "an extensive TopicCategoryCode vocabulary with ~170 DDE geoscience "
        "sub-categories",
        "an extensive TopicCategoryCode vocabulary with 191 DDE geoscience "
        "sub-categories",
    ),
    # The three SV_ServiceIdentification rows and the summary row claimed
    # "Partially mapped". tools/check_mapping_doc.py found that WebAPI,
    # documentation, potentialAction and serviceType appear nowhere in either
    # converter, case-insensitively -- so nothing is carried and the claim
    # overstated the code. Verified 2026-11-15.
    (
        "Partially mapped.CDIF supports WebAPI typebut DDE has 37+ specific"
        "service type codes(data/knowledge/platform/thematic/vocabulary "
        "services).",
        "NOT mapped. CDIF defines a WebAPI type, but neither converter "
        "mentions it, so no service type is carried in either direction. DDE "
        "has 37+ specific service type codes "
        "(data/knowledge/platform/thematic/vocabulary services).",
    ),
    (
        "Partially mapped.CDIF has Action withtarget/result but DDEuses "
        "free-text operation names.",
        "NOT mapped. CDIF has Action with target/result, but neither converter "
        "mentions schema:potentialAction. DDE uses free-text operation names.",
    ),
    (
        "Partially mapped.CDIF has documentation URL;DDE has full "
        "CI_OnlineResource.",
        "NOT mapped. CDIF has a documentation URL, but neither converter "
        "mentions schema:documentation. DDE has a full CI_OnlineResource.",
    ),
    (
        "| Partial (WebAPI only) | Partially mapped |",
        "| Partial (WebAPI only) | NOT mapped |",
    ),
]

ENTITIES = (
    ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
    ("&quot;", '"'), ("&apos;", "'"),
)


def cell_text(fragment):
    """Flatten a run of Word XML to one line, escaping markdown table pipes."""
    text = re.sub(r"</w:p>", " \u0001 ", fragment)
    text = re.sub(r"<[^>]+>", "", text)
    for entity, char in ENTITIES:
        text = text.replace(entity, char)
    text = text.replace("\u0001", " ")
    return " ".join(text.split()).replace("|", BACKSLASH + "|")


def convert(docx_path):
    xml = zipfile.ZipFile(docx_path).read("word/document.xml").decode("utf-8", "replace")
    body = re.search(r"<w:body>.*</w:body>", xml, re.S).group(0)
    blocks = re.findall(r"(<w:tbl>.*?</w:tbl>|<w:p\b.*?</w:p>)", body, re.S)

    out = []
    for block in blocks:
        if block.startswith("<w:tbl>"):
            rows = re.findall(r"<w:tr\b.*?</w:tr>", block, re.S)
            lines = []
            for i, row in enumerate(rows):
                cells = [cell_text(c) for c in re.findall(r"<w:tc>.*?</w:tc>", row, re.S)]
                lines.append("| " + " | ".join(cells) + " |")
                if i == 0:
                    lines.append("|" + "|".join([" --- "] * len(cells)) + "|")
            out.append("\n".join(lines))
            continue

        text = cell_text(block)
        if not text:
            continue
        style = re.search(r'w:val="(Heading\d|Title)"', block)
        if style:
            name = style.group(1)
            # Title -> #, Heading1 -> ##, so the document has one h1
            level = 1 if name == "Title" else min(int(name[-1]) + 1, 6)
            out.append("#" * level + " " + text)
        else:
            out.append(text)

    return "\n\n".join(out) + "\n"


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "cdif-DDE-metadata-mapping.docx"
    dst = sys.argv[2] if len(sys.argv) > 2 else "cdif-DDE-metadata-mapping.md"

    md = convert(src)
    applied = 0
    for old, new in CORRECTIONS:
        if old in md:
            md = md.replace(old, new)
            applied += 1
        else:
            print("  WARNING: correction target not present: %s..." % old[:60])

    io.open(dst, "w", encoding="utf-8", newline="\n").write(BANNER + md)
    print("  wrote %s" % dst)
    print("  corrections applied: %d of %d" % (applied, len(CORRECTIONS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
