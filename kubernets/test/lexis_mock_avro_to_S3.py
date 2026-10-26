import boto3
import io
import random
import time

from fastavro import parse_schema
from fastavro.write import writer
from fastavro.read import reader

#aws配置
ACCOUNT_ID = "123456789012"
ROLE_ARN = f"arn:aws:iam::867660044892:role/lexis-s3-writer-role"
BUCKET_NAME = "lexis-lake"

# Avro Schema
SCHEMA = {
    "type": "record",
    "name": "LexisArticleEvent",
    "namespace": "com.lexis",
    "fields": [
        {"name": "article_id",     "type": "string"},
        {"name": "title",         "type": "string"},
        {"name": "author",        "type": "string"},
        {"name": "practice_area", "type": "string"},
        {"name": "views",         "type": "int"},
        {"name": "published_at",  "type": {"type": "long", "logicalType": "timestamp-millis"}},
    ]
}
schema = parse_schema(SCHEMA)

#模拟数据
def generate_batch(n=50):
    titles = [
        "股权转让协议效力认定",
        "劳动法下竞业限制实务",
        "GDPR 与跨境数据传输",
        "破产重整中的债权申报",
        "知识产权侵权赔偿计算",
    ]
    areas = ["Corporate", "Labor", "Data", "Bankruptcy", "IP"]
    authors = ["Li Wei", "Wang Fang", "Chen Jun", "Zhang Min"]

    records = []
    for i in range(n):
        records.append({
            "article_id": f"A-{1000 + i}",
            "title": random.choice(titles),
            "author": random.choice(authors),
            "practice_area": random.choice(areas),
            "views": random.randint(0, 5000),
            "published_at": int(time.time() * 1000),
        })
    return records


# Avro 序列化
def serialize_avro(records):
    buf = io.BytesIO()
    writer(buf, schema, records)
    return buf.getvalue()

# 反序列化
def read_avro(avro_bytes):
    buf = io.BytesIO(avro_bytes)
    return list(reader(buf))

#assume role,写 S3
def write_to_s3(avro_bytes, key):
    print(f" [1/4] 调用 sts.assume_role ...")
    print(f"       RoleArn: {ROLE_ARN}")

    sts = boto3.client("sts")
    try:
        resp = sts.assume_role(
            RoleArn=ROLE_ARN,
            RoleSessionName="local-avro-writer",
            DurationSeconds=3600,
        )
    except Exception as e:
        print(f" assume_role 失败: {e}")
        raise

    c = resp["Credentials"]
    print(f" [2/4] assume_role 成功，拿到临时凭证")
    print(f"       AssumedRoleUser: {resp['AssumedRoleUser']['Arn']}")

    # 用临时凭证建 session
    session = boto3.Session(
        aws_access_key_id=c["AccessKeyId"],
        aws_secret_access_key=c["SecretAccessKey"],
        aws_session_token=c["SessionToken"],
    )
    s3 = session.client("s3", region_name="ap-northeast-1")

    # 写 S3
    print(f" [3/4] 写入 S3 ...")
    print(f"       Bucket: {BUCKET_NAME}")
    print(f"       Key: {key}")
    print(f"       Size: {len(avro_bytes)} bytes")

    try:
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=avro_bytes,
            Metadata={"format": "avro", "domain": "lexis-articles"},
        )
    except Exception as e:
        print(f" S3 写入失败: {e}")
        raise

    print(f" [4/4] 写入完成!")
    print(f"       s3://{BUCKET_NAME}/{key}")

    # 验证：立刻读回来确认
    print(f" 验证：从 S3 读回数据 ...")
    try:
        obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
        read_back = obj["Body"].read()
        print(f"验证成功，S3 返回 {len(read_back)} bytes")
    except Exception as e:
        print(f"验证读取失败: {e}")
        raise

if __name__ == "__main__":
    print("=" * 60)
    print(" 律商 Avro → S3 模拟 Pipeline")
    print("=" * 60)

    # 0. 检查当前身份
    print("\n 检查本地身份 ...")
    try:
        sts = boto3.client("sts")
        identity = sts.get_caller_identity()
        print(f"   Account: {identity['Account']}")
        print(f"   Arn:     {identity['Arn']}")
    except Exception as e:
        print(f" 无法获取身份，AWS 凭证未配置: {e}")
        exit(1)

    # 1. 生成数据
    print("\n 生成模拟数据 ...")
    records = generate_batch(50)
    print(f"   生成 {len(records)} 条记录")
    print(f"   示例: {records[0]['title']}")

    # 2. 序列化
    print("\n Avro 序列化 ...")
    avro_bytes = serialize_avro(records)
    print(f"   Avro 大小: {len(avro_bytes)} bytes")

    # 3. 验证本地能读回来
    decoded = read_avro(avro_bytes)
    print(f"   本地反序列化验证:  读回 {len(decoded)} 条")

    # 4. 写 S3（assume role → put_object）
    print("\n  写入 S3 ...")
    key = "raw/avro/2026/10/10/articles-001.avro"
    write_to_s3(avro_bytes, key)

    print("\n" + "=" * 60)
    print(" 全部完成！")
    print(f"   S3 路径: s3://{BUCKET_NAME}/{key}")
    print("=" * 60)