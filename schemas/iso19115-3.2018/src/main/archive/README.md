# Archived stylesheets

Kept for reference, deliberately outside `src/main/plugin/`.

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
