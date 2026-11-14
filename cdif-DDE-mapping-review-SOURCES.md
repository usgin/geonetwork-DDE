# Review: `cdif-DDE-metadata-mapping.docx` against mBB `_sources` (bleeding edge)

Reviewed 2026-11-14. Document under review is dated **2026-03-09** ("Branch: DDEconfig | Base:
GeoNetwork 4.4.9").

This review reads the document against metadataBuildingBlocks' **working tree**, which contains
unreleased changes. It is deliberately *not* the conformance standard for the fork — dde-geonetwork's
CDIF support targets the release profiles, reviewed in `cdif-DDE-mapping-review-RELEASE.md`. Treat
this document as a forward warning list: what will break when the current `_sources` state is
released.

## Baseline

`C:\GithubC\USGIN\metadataBuildingBlocks`, `main` at **`273aee68f0`** (the merge of PR #91,
2026-11-14), specifically:

- `_sources/profiles/cdifCompositeProfile/cdifComplete/` and the six profiles it composes:
  `cdifCore`, `cdifDiscovery`, `cdifDataDescription`, `cdifDataStructure`, `cdifManifest`,
  `cdifProvenance` — compared via their `resolvedSchema.json`
- `_sources/profiles/cdifProfile/cdifCodelist/rules.shacl` for the shape change

DDE side: `DDEMetadataXSD_20240103.xsd`, namespace
`https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`.

## Verdict

**Two breaking divergences, both arising after the document was written, one of which invalidates
working code in this fork.** Property coverage itself is fine: 50 of the 52 CDIF property tokens the
document cites are present in `_sources`, the same two absences as in the release.

The structural and DDE-side findings (S3, S4, S5) are identical to the release review and are
summarised rather than repeated.

## Findings

### S1. `prov:used` role-keyed wrappers are no longer accepted — this breaks both fork XSLTs

The most consequential change. `_sources` `cdifCore` now states:

> Role-keyed wrappers (an object whose key names a role, with no `@id`) are not accepted; in the
> schema.org implementation what an activity used is recorded with `schema:instrument` and
> `schema:object` instead.

The released v1.1.1 says the opposite — it documents and accepts `schema:instrument`,
`bios:computationalTool` and `bios:reagent` *inside* `prov:used`. The change arrived with mBB PR #83
(merged 2026-11-12), three days ago, and after the release repos were last synced (2026-11-09).

**The fork implements only the old model.** Checked directly:

| XSLT | uses |
|---|---|
| `convert/fromJsonCdif.xsl` (inbound) | `prov:used` — and nothing else |
| `formatter/cdif/iso19115-3-to-cdif.xsl` (outbound) | `prov:used`, `prov:wasGeneratedBy`, `prov:wasDerivedFrom` |

Neither references `schema:instrument`, `schema:object` or `schema:actionProcess`. So when this
reaches a release:

- **Outbound** will emit `prov:used` wrappers that the new schema rejects, and will fail the new
  SHACL rule "A cdifProvActivity must have at least one of `schema:instrument`, `schema:object` or
  `schema:actionProcess`".
- **Inbound** will silently drop instrument/tool/reagent information from records written to the new
  model, because it only looks inside `prov:used`.

This is not hypothetical. Harvesting the same change into XAS-CDIF broke 5 of its 12 release-only
examples in exactly this way (2 JSON Schema errors and 1–53 SHACL violations each), all reporting the
missing `schema:instrument`/`object`/`actionProcess`.

The document's §3.8 and §3.12 provenance rows describe the old model, so they are correct against the
release and **stale against `_sources`**.

### S2. The codelist concept shape now targets different nodes

`cdifCodelist/rules.shacl` was changed on 2026-11-14 (PR #91): `CDIFCodelistConceptShape` no longer
uses `sh:targetClass skos:Concept` but

```
sh:targetObjectsOf skos:hasTopConcept, skos:narrower ;
```

The constraints are unchanged; what changed is which nodes they apply to. Two effects relevant to the
mapping:

- Concepts that are objects of `skos:narrower`/`skos:hasTopConcept` but **not typed**
  `skos:Concept` are now in scope where they were not before. This is not a pure relaxation.
- Standalone concepts — the inline-concept pattern in data-structure records — are no longer
  targeted, so a concept that only appears as a semantic annotation is no longer required to carry
  `skos:notation` or an IRI `skos:inScheme`.

The document's §3.4 keyword/topic-category rows do not mention concept-shape constraints, so nothing
there is wrong. The risk is the reverse: output that validated under the release shape may validate
differently here, in both directions.

### S3. §2.2's description of CDIF's composition is stale

Same as the release review. `cdifMandatory` and `cdifOptional` no longer exist. `cdifComplete`
composes `cdifCore`, `cdifDiscovery`, `cdifDataDescription`, `cdifDataStructure`, `cdifManifest`,
`cdifProvenance` — verifiable in `cdifComplete/schema.yaml` lines 9–14.

### S4. Three structural counts in §2.1 are wrong

Same as the release review, since the DDE schema is the same on both sides:

| document asserts | actual |
|---|---|
| 13 complex types | **14** |
| 14 codelist + 2 utility simple types | **correct** (`DateTime`, `NilReasonType`) |
| "~170" `TopicCategoryCode` sub-categories | **191** |
| "21+" `AcquisitionCode` values | **21**, correct |

### S5. §3.6's geologic-time rows are correct here too

`_sources` carries the same `time:ProperInterval` / `intervalStartedBy` / `hasBeginning` /
`numericPosition` / `hasTRS` vocabulary as v1.1.1, and the fork's outbound branch became conformant
with it in commit `c699c262ea` (2026-11-13). No divergence between the baselines on temporal extent.

## Recommendations

1. **Plan the provenance migration now, do not make it yet.** The fork targets the release, so
   changing the XSLTs today would break conformance with v1.1.1. The work to queue:
   - outbound: emit `schema:instrument` / `schema:object` / `schema:actionProcess` on the activity
     instead of role-keyed wrappers under `prov:used`
   - inbound: read both forms, so the harvester keeps working across the transition
   - then re-validate against both baselines before switching the declared target
2. **Watch `profile-provenance` specifically.** It has no release tag, so its `main` is where this
   change will land first for anyone pinning to "the release profiles" — the release review's
   Finding R1 explains why that pin does not insulate the fork.
3. **Mark §3.8 and §3.12 as release-only.** The provenance rows are correct against v1.1.1 and wrong
   against `_sources`; a document that does not say which baseline it describes will be read as
   describing whichever the reader has checked out.
4. Apply the §2.2 and count fixes (S3, S4) — they are baseline-independent.

## Scope of this review

Verified: the `_sources` baseline commit; presence of all 52 cited CDIF property tokens; the
`prov:used` contract in `cdifCore`; the `cdifCodelist` shape change; the composition of
`cdifComplete`; the DDE XSD counts; and which prov model each fork XSLT implements.

**Not verified:** the semantic correctness of each of the ~200 individual mapping rows, and whether
any *other* `_sources` change since 2026-03-09 affects a row not examined here. The two divergences
above were found by checking the areas that recent mBB history touched; a full row-by-row audit
against `_sources` has not been done.
