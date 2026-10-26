import boto3
import json
from datetime import datetime, timezone

s3 = boto3.client("s3")
BUCKET = "lexis-lake"

def lambda_handler(event, context):
    print(f"RECORDS COUNT: {len(event.get('Records', []))}")

    now = datetime.now(timezone.utc)

    for record in event["Records"]:
        # Kinesis 每条 record 的唯一标识
        seq = record["kinesis"]["sequenceNumber"]
        shard = record["eventSourceARN"].split("/")[-1]
        data_b64 = record["kinesis"]["data"]

        # 用 shard + sequenceNumber 做幂等 key
        # 重试时覆盖同一个文件，不会多出来
        key = (
            f"raw/kinesis-debug/"
            f"year={now.year}/month={now.month:02d}/day={now.day:02d}/"
            f"shard={shard}/"
            f"seq={seq}.json"
        )

        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps({
                "shard": shard,
                "sequenceNumber": seq,
                "data_b64": data_b64,
                "approxArrival": record["kinesis"].get("approximateArrivalTimestamp"),
            }, default=str).encode("utf-8"),
            ContentType="application/json"
        )

        print(f"  wrote: {key}")

    return {"ok": True, "processed": len(event.get("Records", []))}