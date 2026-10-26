import boto3
import base64
import fastavro
import io
from datetime import datetime, timezone

s3 = boto3.client("s3")
BUCKET = "lexis-lake"

# Avro schema（必须和 producer 端一致）
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

def lambda_handler(event, context):
    print(f"RECORDS COUNT: {len(event.get('Records', []))}")

    now = datetime.now(timezone.utc)
    batch_records = []

    for record in event["Records"]:
        # 1. 从 Kinesis event 里取 base64 编码的 data
        data_b64 = record["kinesis"]["data"]
        raw_bytes = base64.b64decode(data_b64)

        # 2. fastavro 反序列化
        reader = fastavro.reader(io.BytesIO(raw_bytes))
        for avro_record in reader:
            batch_records.append(avro_record)
            print(f"  decoded: {avro_record['article_id']} | {avro_record['title']}")

    if not batch_records:
        print("No records decoded, skipping S3 write")
        return {"ok": True, "processed": 0}

    # 3. 把这批 records 写成一个 Avro 文件写回 S3
    out_buf = io.BytesIO()
    fastavro.writer(out_buf, SCHEMA, batch_records)
    out_buf.seek(0)

    key = (
        f"raw/avro/"
        f"year={now.year}/month={now.month:02d}/day={now.day:02d}/"
        f"articles-{context.aws_request_id}.avro"
    )

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=out_buf.read(),
        ContentType="application/avro",
    )

    print(f"✅ wrote {len(batch_records)} records to s3://{BUCKET}/{key}")
    return {"ok": True, "processed": len(batch_records)}