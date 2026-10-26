import fastavro
import boto3
from io import BytesIO

s3 = boto3.client("s3")
obj = s3.get_object(Bucket="lexis-lake", Key="raw/avro/year=2026/month=10/day=11/articles-xxx.avro")
reader = fastavro.reader(BytesIO(obj["Body"].read()))
for r in reader:
    print(r)