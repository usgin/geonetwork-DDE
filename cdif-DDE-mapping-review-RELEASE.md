# Review: `cdif-DDE-metadata-mapping.docx` against the **released** CDIF profiles

Reviewed 2026-11-14. Document under review is dated **2026-03-09** ("Branch: DDEconfig | Base:
GeoNetwork 4.4.9").

This is the review that matters for the fork, because dde-geonetwork's CDIF support targets the
**release** profiles, not mBB's working tree. A companion review against the bleeding edge is in
`cdif-DDE-mapping-review-SOURCES.md`; where the two disagree, this one governs what the fork should
do today.

## Baseline

| profile repo | release used | note |
|---|---|---|
| `profile-core` | **v1.1.1** | |
| `profile-discovery` | **v1.1.1** | |
| `profile-datadescription` | **v1.1.1** | |
| `profile-datastructure` | **v1.1.1** | |
| `profile-manifest` | **v1.1.1** | |
| `profile-codelist` | **v1.1.1** | |
| `profile-provenance` | **no tag exists** | see Finding R1 |
| `profile-conceptscheme` | **no tag exists** | see Finding R1 |

Compared against each repo's tagged `*StructuredSchema.json`, not the `updates` branch and not
`main`. DDE side: `DDEMetadataXSD_20240103.xsd` from `usgin/dde-metadata`, target namespace
`https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`.

## Verdict

**Substantially consistent.** Of 52 CDIF property tokens the document cites, **50 are present** in
the v1.1.1 release schemas. The two that are not (`cdi:TabularData`, `cdi:DataCube`) the document
already marks as unmapped. The provenance and geologic-time mappings — the two areas most likely to
have rotted — both hold against v1.1.1.

Four findings, one of which is a genuine gap in the release set rather than an error in the document.

## Findings

### R1. There is no released provenance profile, so §3.8 and §3.12 cannot be pinned

`profile-provenance` carries **no tags at all**; neither does `profile-conceptscheme`. Their `main`
*is* the leading edge, because neither has had a formal release.

This matters for the decision to target release profiles: the document's provenance rows
(§3.8 `prov:wasGeneratedBy`, `prov:wasDerivedFrom`, §3.12 `prov:*` handling) describe a mapping
against a profile that has no release to target. The crosswalks therefore depend on an unreleased
profile whether or not that was intended.

Two consequences worth deciding explicitly:

- The provenance mapping is validated here only against `profile-core` v1.1.1, which *does* define
  the `prov:used` contract the crosswalks rely on.
- `profile-provenance`'s `main` is already diverging from that contract — see
  `cdif-DDE-mapping-review-SOURCES.md` Finding S1. Pinning to "the release" does not insulate the
  fork from that change; it only defers it.

### R2. §2.2's description of CDIF's composition is stale

The document says CDIF Complete is "composed from CDIFDiscovery (**cdifMandatory** + **cdifOptional**)
plus extensions for archive distributions, tabular data, and data cubes."

Neither `cdifMandatory` nor `cdifOptional` exists any more, in the release repos or in mBB. The
mandatory/optional split was refactored away. There is a single `cdifDiscovery` profile, released at
v1.1.1, and the complete profile composes six blocks: core, discovery, data description, data
structure, manifest, provenance.

Low impact — it is a description, not a mapping — but it will mislead anyone using §2.2 to navigate
the register.

### R3. Three structural counts in §2.1 are wrong, one materially

Checked directly against `DDEMetadataXSD_20240103.xsd`:

| document asserts | actual | |
|---|---|---|
| 13 complex types | **14** | minor |
| 14 codelist + 2 utility simple types | **14 + 2** (`DateTime`, `NilReasonType`) | correct |
| "~170 DDE geoscience sub-categories" in `TopicCategoryCode` | **191 enumerations** | understates by ~12% |
| "21+" `AcquisitionCode` values | **21** | correct |

The `TopicCategoryCode` figure is the one worth fixing: §6.1 ranks gaps partly by vocabulary size,
and 191 is a stronger argument than 170 for the recommendation it is supporting.

### R4. §3.6's "Mapped" claims for geologic time were aspirational until 2026-11-13

The rows describing `time:ProperInterval` with `time:intervalStartedBy` / `time:intervalFinishedBy`,
`time:hasBeginning` / `time:hasEnd`, `time:numericPosition` and `time:hasTRS` are **correct against
v1.1.1** — `profile-discovery` v1.1.1 contains all of them.

But the fork did not actually emit conformant output for any of those rows until commit
`c699c262ea` (2026-11-13), which fixed four defects in the outbound geologic branch: scalar `@type`
where arrays are required, `time:hasTRS` emitted as `{"@id": …}` instead of a string,
`schema:value` instead of `time:numericPosition`, and bound selection by document order so an end
bound with no age silently took the next interval's begin value.

So the document's "Harvester Status: Mapped" was a statement of intent for eight months. Nothing to
change in the mapping table; worth a dated note so the claim is not read as having been verified in
March.

## Confirmed consistent with v1.1.1

Stated so the findings above are not mistaken for a general verdict:

- **The `prov:used` contract the crosswalks use is correct.** v1.1.1 `profile-core` documents and
  accepts role-keyed wrappers inside `prov:used` — `schema:instrument`, `bios:computationalTool`,
  `bios:reagent`. Both fork XSLTs (`convert/fromJsonCdif.xsl` inbound,
  `formatter/cdif/iso19115-3-to-cdif.xsl` outbound) use `prov:used` and nothing else, which is
  exactly right for this baseline.
- **The geologic-time vocabulary is all present** at v1.1.1, as above.
- **50 of 52 cited property tokens exist**, including every `schema:*` the mapping table depends on,
  plus `dqv:hasQualityMeasurement`, `prov:wasGeneratedBy`, `prov:wasDerivedFrom`,
  `dcterms:conformsTo`, `geosparql:hasGeometry` and `spdx:checksum`.
- **The DDE namespace is current**: `…/standards/dde/ds01/metadata/1.0`, matching the XSD the
  document names.

## Recommendations

1. **Pin the fork's conformance target explicitly.** State in `agents.md` that the CDIF crosswalks
   target the v1.1.1 profile releases, and record the provenance gap from Finding R1 rather than
   leaving it implicit.
2. **Fix §2.2 and the three counts** (R2, R3). Cheap, and §2.2 is actively misleading.
3. **Date the §3.6 status column** (R4), so "Mapped" reads as verified-on rather than claimed-in-March.
4. **Treat `cdi:TabularData` / `cdi:DataCube` phrasing with care.** §3.12 calls them "CDIF-specific
   data description extensions"; neither token appears anywhere in the release schemas. If they are
   DDI-CDI classes reached by some other name, say which; otherwise the row implies a CDIF feature
   that does not exist under that name.

## Scope of this review

Verified: the baseline versions; presence of all 52 cited CDIF property tokens; the provenance
contract; the geologic-time vocabulary; the DDE XSD's type and enumeration counts; the composition
of the complete profile; and which prov model each fork XSLT implements.

**Not verified:** the semantic correctness of each of the ~200 individual mapping rows. Checking that
`MD_Identification/abstract` really should be `schema:description`, row by row, is a separate
exercise; this review establishes that the schemas, vocabularies and contracts the rows depend on
are the ones the release actually defines.
