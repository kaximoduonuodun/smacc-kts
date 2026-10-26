import boto3, json

sts = boto3.client("sts")
resp = sts.assume_role(
    RoleArn="arn:aws:iam::867660044892:role/lexis-s3-writer-role",
    RoleSessionName="local-sim-prod",
    DurationSeconds=3600,
)

c = resp["Credentials"]
session = boto3.Session(
    aws_access_key_id=c["AccessKeyId"],
    aws_secret_access_key=c["SecretAccessKey"],
    aws_session_token=c["SessionToken"],
)

s3 = session.client("s3", region_name="ap-northeast-1")
s3.put_object(
    Bucket="lexis-lake",
    Key="raw/_test_from_assumed_role.json",
    Body=json.dumps({"ok": True}).encode(),
)
print("written by assumed role:", resp["AssumedRoleUser"])