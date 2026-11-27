# Advanced topics {#extra}

## GeoNetwork API

In recent releases most of GeoNetworks functionality is exposed via a centralised API based on OpenApi. An optimal approach to get started with the API is via the Interactive documentation page provided by OpenAPI. This page is accessibly via <http://localhost:8080/geonetwork/doc/api>.

![](img/apidoc.png){width="400px"}

The page describes each of the methods and its properties, but also offers the capability to try out any operation via a web form.

## Kibana Dashboard

Kibana is an optional component which can be installed with Elastic Search. Kibana offers a dynamic way to create visualisations of the contentn of the Elastc Search index.

The GeoNetwork community has prepared some sample visualisations. Load the samples from <https://github.com/geonetwork/core-geonetwork/blob/4.0.x/es/es-dashboards/data/export.ndjson> via the 'Saved objects --> Import' option in Kibana.

If installed, you can access kibana from the GeoNetwork admin interface. To access the Kibana interface you need to be logged in as administrator.

Read more about the usage of kibana at <https://www.elastic.co/guide/en/kibana/current/introduction.html>

## Search engines

Search engines provide a good mechanism for wide data discovery for public portals. The process of having catalogue content ingested by search engine crawlers requires some attention. The search engine expects to find robots.txt, at the root of the domain. Robots.txt contains a reference to the sitemap /srv/api/sitemap. Alternatively you can register the sitemap manually at individual search engines.

GeoNetwork includes on any html representation of a metadata record a representation of that record in schema.org encoded as json-ld. This enables the search engine to extract the information in a structured way.

### Sitemap formats

The sitemap at `/srv/api/sitemap` takes an optional `format` parameter that chooses
how each listed record is serialised — that is, what each `<loc>` URL resolves to:

| `format`         | each `<loc>` resolves to                        | available for                       |
|------------------|-------------------------------------------------|-------------------------------------|
| `html` (default) | the record's landing page (with schema.org JSON-LD embedded, as above) | every record |
| `xml`            | the record as stored, `…/api/records/{uuid}/formatters/xml` | every record            |
| `cdif`           | CDIF JSON-LD, `…/formatters/cdif`               | schemas providing a `cdif` formatter |
| `dde`            | DDE XML, `…/formatters/dde`                      | schemas providing a `dde` formatter |

`cdif` and `dde` are formatters contributed by this fork's `iso19115-3.2018` schema
plugin; a stock catalogue offers `html` and `xml`. The `cdif` and `dde` sitemaps list
only the records whose schema provides that formatter, so a record that cannot be
rendered in the requested serialisation is omitted rather than listed with a URL that
would fail.

Each sitemap carries a single serialisation. The [sitemaps.org
schema](https://www.sitemaps.org/protocol.html) has no element for the format of what
a `<loc>` points at, so a catalogue offering several serialisations publishes one
sitemap per format — `?format=cdif` and `?format=dde` are distinct sitemaps, not one
list that labels each entry. Point a crawler or harvester at the one it understands.

For catalogues larger than 2500 records the response is a sitemap *index*: a list of
pages, each fetched with `?doc=N`, that carries the chosen format through
(`?format=cdif&doc=2`). `robots.txt` advertises the default sitemap only.
