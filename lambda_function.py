import boto3
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    destination_bucket = os.environ['DEST_BUCKET']
    
    copy_source = {'Bucket': source_bucket, 'Key': key}
    
    # Copy the file
    s3.copy_object(CopySource=copy_source, Bucket=destination_bucket, Key=key)
    
    # Optionally, delete the file from the source bucket
    # s3.delete_object(Bucket=source_bucket, Key=key)
    
    print(f"File {key} moved from {source_bucket} to {destination_bucket}")
