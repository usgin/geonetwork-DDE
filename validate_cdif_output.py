"""Validate CDIF JSON-LD formatter output from GeoNetwork against the
CDIFcomplete JSON Schema.

Usage:
    python validate_cdif_output.py                  # validate all records
    python validate_cdif_output.py UUID1 UUID2 ...  # validate specific records
    python validate_cdif_output.py --schema discovery  # use CDIFDiscovery schema
    python validate_cdif_output.py --max 10         # limit to 10 records
    python validate_cdif_output.py --save-failures  # save failing output to files

Requires:
    - GeoNetwork running at localhost:8080 (or set GEONETWORK_URL env var)
    - Elasticsearch running at localhost:9200 (or set ES_URL env var)
    - jsonschema >= 4.18 (pip install jsonschema)
    - CDIFcomplete resolved schema at the path below (or set CDIF_SCHEMA_DIR env var)
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from jsonschema import Draft202012Validator

# --- Configuration -----------------------------------------------------------

GEONETWORK_URL = os.environ.get("GEONETWORK_URL", "http://localhost:8080/geonetwork")
ES_URL = os.environ.get("ES_URL", "http://localhost:9200")
CDIF_SCHEMA_DIR = os.environ.get(
    "CDIF_SCHEMA_DIR",
    r"C:\Users\smrTu\OneDrive\Documents\GithubC\USGIN"
    r"\metadataBuildingBlocks\_sources\profiles\cdifProfiles",
)

SCHEMAS = {
    "complete": os.path.join(CDIF_SCHEMA_DIR, "CDIFcomplete", "resolvedSchema.json"),
    "discovery": os.path.join(CDIF_SCHEMA_DIR, "CDIFDiscovery", "resolvedSchema.json"),
}


# --- Helpers -----------------------------------------------------------------

def fetch_json(url):
    """Fetch JSON from a URL, return parsed dict."""
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def get_all_uuids(es_url, max_records=None):
    """Query Elasticsearch for all record UUIDs in gn-records index."""
    size = max_records or 10000
    body = json.dumps({"size": size, "_source": ["uuid"], "query": {"match_all": {}}})
    req = urllib.request.Request(f"{es_url}/gn-records/_search",
                                data=body.encode(),
                                headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())
    return [hit["_id"] for hit in data["hits"]["hits"]]


def validate_record(uuid, validator, geonetwork_url):
    """Fetch CDIF output for a UUID and validate it.

    Returns (uuid, cdif_doc_or_None, errors_list, error_message_or_None).
    """
    url = f"{geonetwork_url}/srv/api/records/{urllib.request.quote(uuid, safe='')}/formatters/cdif"
    try:
        doc = fetch_json(url)
    except urllib.error.HTTPError as e:
        return uuid, None, [], f"HTTP {e.code} fetching formatter"
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        return uuid, None, [], str(e)

    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.absolute_path))
    return uuid, doc, errors, None


def print_errors(errors, verbose=False):
    """Print validation errors, grouping by path."""
    seen = {}
    for e in errors:
        path = "/".join(str(p) for p in e.absolute_path) or "(root)"
        msg = e.message[:200]
        key = (path, msg)
        if key not in seen:
            seen[key] = 0
        seen[key] += 1

    for (path, msg), count in seen.items():
        suffix = f" (x{count})" if count > 1 else ""
        print(f"    [{path}] {msg}{suffix}")
        if verbose:
            # Find the original error for schema context
            for e in errors:
                p = "/".join(str(p2) for p2 in e.absolute_path) or "(root)"
                if p == path and e.message[:200] == msg:
                    if e.schema_path:
                        print(f"      schema path: {'/'.join(str(s) for s in e.schema_path)}")
                    break


# --- Main --------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Validate CDIF JSON-LD output from GeoNetwork against CDIF JSON Schema")
    parser.add_argument("uuids", nargs="*",
                        help="Specific record UUIDs to validate (default: all)")
    parser.add_argument("--schema", choices=list(SCHEMAS.keys()), default="complete",
                        help="Which CDIF schema to validate against (default: complete)")
    parser.add_argument("--max", type=int, default=None,
                        help="Maximum number of records to validate")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Show schema paths for each error")
    parser.add_argument("--save-failures", action="store_true",
                        help="Save failing CDIF output to files in cdif_failures/")
    args = parser.parse_args()

    # Load schema
    schema_path = SCHEMAS[args.schema]
    if not os.path.exists(schema_path):
        print(f"ERROR: Schema not found at {schema_path}")
        sys.exit(1)
    with open(schema_path) as f:
        schema = json.load(f)
    validator = Draft202012Validator(schema)
    print(f"Schema: {args.schema} ({os.path.basename(schema_path)})")

    # Get record UUIDs
    if args.uuids:
        uuids = args.uuids
    else:
        try:
            uuids = get_all_uuids(ES_URL, args.max)
        except Exception as e:
            print(f"ERROR: Could not fetch UUIDs from Elasticsearch: {e}")
            sys.exit(1)
    if args.max and not args.uuids:
        uuids = uuids[:args.max]
    print(f"Records to validate: {len(uuids)}")
    print()

    # Validate each record
    pass_count = 0
    fail_count = 0
    error_count = 0
    all_error_paths = {}

    for uuid in sorted(uuids):
        uuid, doc, errors, fetch_error = validate_record(uuid, validator, GEONETWORK_URL)

        if fetch_error:
            error_count += 1
            print(f"  ERROR  {uuid} -- {fetch_error}")
            continue

        if errors:
            fail_count += 1
            print(f"  FAIL   {uuid} ({len(errors)} errors)")
            print_errors(errors, args.verbose)

            # Track error frequency by path
            for e in errors:
                path = "/".join(str(p) for p in e.absolute_path) or "(root)"
                all_error_paths[path] = all_error_paths.get(path, 0) + 1

            # Save failing output
            if args.save_failures and doc:
                os.makedirs("cdif_failures", exist_ok=True)
                safe_name = uuid.replace(":", "_").replace("/", "_")
                out_path = os.path.join("cdif_failures", f"{safe_name}.json")
                with open(out_path, "w") as f:
                    json.dump(doc, f, indent=2)
        else:
            pass_count += 1
            print(f"  PASS   {uuid}")

    # Summary
    print()
    print(f"{'='*60}")
    print(f"Results: {pass_count} PASS, {fail_count} FAIL, {error_count} ERROR "
          f"(of {len(uuids)} records)")

    if all_error_paths:
        print()
        print("Most common error paths:")
        for path, count in sorted(all_error_paths.items(), key=lambda x: -x[1])[:15]:
            print(f"  {count:4d}x  {path}")

    sys.exit(1 if fail_count > 0 or error_count > 0 else 0)


if __name__ == "__main__":
    main()
