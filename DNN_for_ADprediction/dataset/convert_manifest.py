#!/usr/bin/env python3
"""Convert Illumina 450K manifest CSV to GEO GPL13534-11288.txt format.

The code expects a TSV file with 37 header/comment lines (skipped via header=37
or skiprows=37), then tab-separated data with columns including:
  ID, UCSC_RefGene_Name, UCSC_RefGene_Group

The Illumina manifest CSV has 7 header lines, then comma-separated data with
'Name' as the probe ID column.
"""
import csv
import gzip
import sys

INPUT = "GPL13534_manifest.csv.gz"
OUTPUT = "GPL13534-11288.txt"

# Read the CSV, skip 7 header lines, extract needed columns
print(f"Reading {INPUT}...")
rows = []
with gzip.open(INPUT, "rt") as f:
    # Skip 7 header lines
    for _ in range(7):
        next(f)
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    print(f"CSV columns: {fieldnames[:10]}...")
    for row in reader:
        rows.append(row)

print(f"Read {len(rows)} probes")

# Write as TSV with 37 comment/header lines (to match GEO format)
print(f"Writing {OUTPUT}...")
with open(OUTPUT, "w") as f:
    # Write 37 comment lines (lines 0-36) then column header at line 37
    for i in range(37):
        if i == 0:
            f.write(f"# Platform = GPL13534\n")
        elif i == 1:
            f.write(f"# Organism = Homo sapiens\n")
        elif i == 2:
            f.write(f"# Converted from Illumina HumanMethylation450 manifest\n")
        else:
            f.write(f"#\n")

    # Map CSV column names to GEO-style names
    # The code uses: ID, UCSC_RefGene_Name, UCSC_RefGene_Group
    # CSV has: Name (=ID), UCSC_RefGene_Name, UCSC_RefGene_Group
    geo_columns = ["ID"]
    csv_to_geo = {"Name": "ID"}
    for col in fieldnames:
        if col != "Name":
            geo_columns.append(col)

    # Write column header (line 37, 0-indexed line 36)
    f.write("\t".join(geo_columns) + "\n")

    # Write data rows
    for row in rows:
        vals = [row.get("Name", "") or ""]
        for col in fieldnames:
            if col != "Name":
                vals.append(row.get(col, "") or "")
        f.write("\t".join(vals) + "\n")

print(f"Done. Wrote {len(rows)} rows to {OUTPUT}")
