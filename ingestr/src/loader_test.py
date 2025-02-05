import os
import csv
import gzip
import json
import tempfile
from typing import List

import pytest
import pyarrow.parquet

from loader import load_dlt_file

TESTDATA = [
    {
        "name": "Jhon",
        "email": "jhon@acme.com"
    },
    {
        "name": "Lisa",
        "email": "lisa@acme.com"
    },
]

def tojsonl(datalist: List[dict]):
    return "\n".join([
        json.dumps(data)
        for data in datalist
    ]).encode()


@pytest.fixture(scope="session", autouse=True)
def testfiles():
    with (
        tempfile.NamedTemporaryFile("w", delete=False) as gzipped_jsonl,
        tempfile.NamedTemporaryFile("w", delete=False) as plain_csv,
        tempfile.NamedTemporaryFile("w", delete=False) as parquet,
    ):
        # gzipped jsonl
        gzipped_jsonl.close()
        writer = gzip.open(gzipped_jsonl.name, "w")
        writer.write(tojsonl(TESTDATA))
        writer.close()

        # csv
        writer = csv.DictWriter(
            plain_csv,
            fieldnames=TESTDATA[0].keys(),
        )
        writer.writeheader()
        writer.writerows(TESTDATA)
        plain_csv.close()

        # parquet
        parquet.close()
        pyarrow.parquet.write_table(
            pyarrow.Table.from_pylist(TESTDATA),
            parquet.name,
        )


        files = [
            gzipped_jsonl.name,
            plain_csv.name,
            parquet.name,
        ]

        yield files

        for file in files:
            os.remove(file)

def test_loader(testfiles):
    for testfile in testfiles:
        data = [
            row for row in load_dlt_file(testfile)
        ]
        assert data == TESTDATA
