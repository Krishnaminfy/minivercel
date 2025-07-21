# infra/s3_setup.py

import boto3
import json
import os
import sys
import mimetypes
import re
import time
from botocore.exceptions import ClientError

REGION = 'ap-south-1'

def validate_bucket_name(bucket_name):
    pattern = r'^[a-z0-9.-]{3,63}$'
    if not re.match(pattern, bucket_name) or '_' in bucket_name:
        print("[ERROR] Invalid bucket name. Use only lowercase letters, numbers, dots (.), or hyphens (-). Underscores (_) are not allowed.")
        sys.exit(1)

def create_bucket(bucket_name):
    s3 = boto3.client('s3', region_name=REGION)

    try:
        # Check if bucket exists
        s3.head_bucket(Bucket=bucket_name)
        print(f"[INFO] Bucket '{bucket_name}' already exists. Skipping creation.")
    except ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            try:
                print(f"[INFO] Creating S3 bucket: {bucket_name}...")
                s3.create_bucket(
                    Bucket=bucket_name,
                    CreateBucketConfiguration={'LocationConstraint': REGION}
                )
                print(f"[SUCCESS] Bucket created.")
            except ClientError as ce:
                print(f"[ERROR] Failed to create bucket: {ce}")
                sys.exit(1)
        elif error_code == 403:
            print(f"[ERROR] Bucket name '{bucket_name}' is already taken globally. Please choose a different name.")
            sys.exit(1)
        else:
            print(f"[ERROR] Unexpected error checking bucket: {e}")
            sys.exit(1)


def set_public_access(bucket_name):
    s3 = boto3.client('s3', region_name=REGION)

    print("[INFO] Configuring public access and website settings...")
    try:
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': False,
                'IgnorePublicAcls': False,
                'BlockPublicPolicy': False,
                'RestrictPublicBuckets': False
            }
        )

        s3.put_bucket_website(
            Bucket=bucket_name,
            WebsiteConfiguration={
                'IndexDocument': {'Suffix': 'index.html'},
                'ErrorDocument': {'Key': 'index.html'}
            }
        )

        policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": f"arn:aws:s3:::{bucket_name}/*"
            }]
        }

        s3.put_bucket_policy(
            Bucket=bucket_name,
            Policy=json.dumps(policy)
        )
        print("[SUCCESS] Public access and website configuration set.")
    except ClientError as e:
        print(f"[ERROR] Failed to set public access or website config: {e}")
        sys.exit(1)

def upload_files(bucket_name, source_dir):
    s3 = boto3.client('s3', region_name=REGION)
    print(f"[INFO] Uploading files from {source_dir} to bucket {bucket_name}...")

    for root, _, files in os.walk(source_dir):
        for file in files:
            full_path = os.path.join(root, file)
            relative_path = os.path.relpath(full_path, source_dir).replace("\\", "/")
            content_type, _ = mimetypes.guess_type(full_path)
            extra_args = {}
            if content_type:
                extra_args['ContentType'] = content_type

            try:
                s3.upload_file(full_path, bucket_name, relative_path, ExtraArgs=extra_args)
                print(f"[UPLOAD] {relative_path}")
            except ClientError as e:
                print(f"[ERROR] Failed to upload {relative_path}: {e}")
                continue

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 s3_setup.py <bucket-name> <code-path>")
        sys.exit(1)

    bucket_name = sys.argv[1].strip().lower().replace('_', '-')
    code_path = sys.argv[2]  #  Corrected line

    validate_bucket_name(bucket_name)
    create_bucket(bucket_name)

    time.sleep(2)  # Optional: prevent race condition after bucket creation

    set_public_access(bucket_name)
    upload_files(bucket_name, code_path)

    website_url = f"http://{bucket_name}.s3-website.{REGION}.amazonaws.com"
    print(f"\n[SUCCESS]  Your static website is deployed at:\n{website_url}")


if __name__ == "__main__":
    main()
