import base64
import boto3
import io
from datetime import datetime, timezone

s3 = boto3.client("s3")

BUCKET = "lexis-lake"
PREFIX = "raw/avro"

def lambda_handler(event, context):
    batch = []

    for record in event["Records"]:
        avro_blob = base64.b64decode(record["kinesis"]["data"])
        batch.append(avro_blob)

    if not batch:
        return {"statusCode": 200, "processed": 0}

    # 把多个 Avro 二进制块拼成一个“多 record 的 Avro 文件”
    now = datetime.now(timezone.utc)
    key = (
        f"{PREFIX}/"
        f"year={now.year}/month={now.month:02d}/day={now.day:02d}/"
        f"articles-{context.request_id}.avro"
    )

    # 这里演示“原样落盘”：把每条 record 的 avro bytes 顺序写
    # 生产里更常见：fastavro.reader 反序列化 → Spark DataFrame → 再写 Parquet
    body = b"".join(batch)

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=body,
        ContentType="application/avro"
    )

    print(f"wrote {len(batch)} records to s3://{BUCKET}/{key}")
    return {"statusCode": 200, "processed": len(batch)}