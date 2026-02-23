#!/bin/bash

# Load deployment info
if [ ! -f .aws-deploy-info ]; then
    echo "Error: .aws-deploy-info not found. Please run ./aws-setup.sh first."
    exit 1
fi

source .aws-deploy-info

echo "Syncing files to S3 bucket: $BUCKET_NAME..."
aws s3 sync . "s3://$BUCKET_NAME/" --exclude ".git/*" --exclude "*.sh" --exclude "*.csv" --exclude "*.json" --exclude ".aws-deploy-info" --exclude ".DS_Store" --profile "$PROFILE"

echo "Invalidating CloudFront cache for distribution: $DIST_ID..."
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --profile "$PROFILE"

echo "Deployment finished!"
