# Archived stylesheets

Kept for reference, deliberately outside `src/main/plugin/`.

Both files here are orphaned halves of a pair. The plugin carried two
near-duplicate converters in each direction, and only one of each was ever
reached:

| direction | live | archived here |
|---|---|---|
| ISO 19115-3 to DDE | `convert/toDDE_20240204.xsl` | `ISO19115-3ToDDE_20240204.xsl` |
| DDE to ISO 19115-3 | `convert/fromDDE-20240405.xsl` | `ddeToISO19115-3_20240208.xsl` |

Both archived files `xsl:import` from `convert/utility/`; both live files import
the same stylesheets from `convert/utilityDDE/`. That directory was renamed at
some point, the live halves were updated, and these two were not -- so neither
has compiled since. Saxon stops at the first missing import. They were still
being packaged into every war.

That placement is the point. `src/assembly/schema-plugin.xml` packages
`src/main/plugin/` wholesale, and the webapp build copies `**/src/main/plugin/**`,
so anything left under `plugin/` ships in the war and is loaded by the catalogue
whether or not it works. A sibling directory is not picked up by either.

## ISO19115-3ToDDE_20240204.xsl

ISO 19115-3 to DDE. A near-duplicate of `convert/toDDE_20240204.xsl`, which is
the live one, reached from `formatter/dde/view.xsl`.

Archived 2026-11-17 because nothing referenced it and it could not have run: its
`xsl:import` names `utility/DDEutilities.xsl`, in a `convert/utility/` directory
that does not exist. The live copy imports `utilityDDE/DDEutilities.xsl`. So the
two had already drifted, and the dead one lost.

It was also still carrying the browse-graphic defect fixed in 511e5d0bef --
reading the image URL from `mcc:linkage` or a `mcc:fileName` starting with
`http`, and nowhere else. Anyone who found this file while looking for the
ISO-to-DDE mapping would have read the wrong, older logic and concluded the bug
was unfixed.

## ddeToISO19115-3_20240208.xsl

DDE to ISO 19115-3. A near-duplicate of `convert/fromDDE-20240405.xsl`, which is
the live one, reached from `fromDDE-any.xsl`.

Archived 2026-11-17, for the same reasons as the file above: unreferenced, and
unable to resolve `utility/create19115-3Namespaces.xsl`.

The duplication was close enough to mislead. Its browse-graphic mapping sits at
lines 1231-1241, the same lines as the live copy, with the same text -- which is
how it came to be cited as the source of the browse-graphic behaviour
investigated in 511e5d0bef, when the records had in fact been produced by
`fromDDE-20240405.xsl`.

`FormatAuditAnalysis20260225.md` still lists this file under "Converters
available". That document is a dated snapshot and has been left as written.
