#!/usr/bin/env python3
"""
Kinesis producer - sends 2 Avro records per run.
article_id rotates: A1/A2, A3/A4, A5/A6...
Counter persisted in ~/.kinesis_counter

# 正常发送（每次 2 条）
python produce_avro_kinesis.py

# 重置 counter（下次从 A1/A2 开始）
python produce_avro_kinesis.py --reset
"""

import boto3
import fastavro
import json
import os
import uuid
from datetime import datetime, timezone

# ---------- config ----------
STREAM_NAME = "lexis-articles-stream"
REGION = "ap-southeast-1"
COUNTER_FILE = os.path.expanduser("~/.kinesis_counter")

TITLES = [
    "AI Breakthrough in 2026",
    "Cloud Cost Optimization Tips",
    "Data Lake vs Data Warehouse",
    "Serverless Best Practices",
    "Kinesis Streaming Patterns",
    "AWS re:Invent Highlights",
    "Python 3.13 Performance Gains",
    "Real-time Analytics at Scale",
]

SCHEMA = {
    "type": "record",
    "name": "Article",
    "fields": [
        {"name": "article_id", "type": "string"},
        {"name": "title", "type": "string"},
        {"name": "views", "type": "int"},
        {"name": "published_at", "type": "string"},
    ],
}
# -----------------------------


def load_counter():
    """Read counter from file, default to 1 if not exists."""
    if os.path.exists(COUNTER_FILE):
        with open(COUNTER_FILE, "r") as f:
            return int(f.read().strip())
    return 1


def save_counter(val):
    """Persist counter to file."""
    with open(COUNTER_FILE, "w") as f:
        f.write(str(val))


def make_record(article_num, titles, base_views):
    """Build a single article record."""
    return {
        "article_id": f"A{article_num}",
        "title": titles[(article_num - 1) % len(titles)],
        "views": base_views + article_num,
        "published_at": datetime.now(timezone.utc).isoformat(),
    }


def serialize_avro(records):
    """Serialize a list of records to Avro bytes."""
    import io

    buf = io.BytesIO()
    fastavro.writer(buf, SCHEMA, records)
    return buf.getvalue()


def send_to_kinesis(kinesis_client, stream_name, records):
    """Send each record to Kinesis with article_id as partition key."""
    sent = 0
    for rec in records:
        payload = serialize_avro([rec])
        kinesis_client.put_record(
            StreamName=stream_name,
            Data=payload,
            PartitionKey=rec["article_id"],
        )
        print(f"  sent {rec['article_id']} | {rec['title']} | views={rec['views']}")
        sent += 1
    return sent


def reset_counter():
    """Delete counter file (for manual reset)."""
    if os.path.exists(COUNTER_FILE):
        os.remove(COUNTER_FILE)
        print("Counter reset. Next run will start from A1/A2.")
    else:
        print("No counter file found. Nothing to reset.")


def main():
    import sys

    # Allow --reset flag
    if len(sys.argv) > 1 and sys.argv[1] == "--reset":
        reset_counter()
        return

    # Load and increment counter
    counter = load_counter()
    # Each run sends 2 records: counter and counter+1
    a_num_1 = counter
    a_num_2 = counter + 1
    counter += 2
    save_counter(counter)

    # Build 2 records
    base_views = (counter - 2) * 10  # just a growing number
    records = [
        make_record(a_num_1, TITLES, base_views),
        make_record(a_num_2, TITLES, base_views),
    ]

    # Send
    kinesis_client = boto3.client("kinesis", region_name=REGION)
    print(f"\nStream: {STREAM_NAME} ({REGION})")
    print(f"Batch: A{a_num_1}/A{a_num_2} (counter={counter-2}→{counter-1})")
    print(f"Time: {datetime.now(timezone.utc).isoformat()}")
    print("---")

    sent = send_to_kinesis(kinesis_client, STREAM_NAME, records)
    print(f"\n✅ Done. Sent {sent} records.\n")


if __name__ == "__main__":
    main()