#!/bin/bash

# Configuration
PROJECT_NAME="pw50-website"
REGION="us-east-1"
# We'll use a unique identifier to avoid bucket name collisions
BUCKET_NAME="pw50-static-site-mediusa-$(date +%s)"
PROFILE="mediusa"

echo "Using profile: $PROFILE"
echo "Creating bucket: $BUCKET_NAME in $REGION..."

# 1. Create S3 Bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$PROFILE"

# Update Bucket Policy for OAC later, or just enable public access for now (simpler for static)
# But OAC is best practice. Let's start with a basic static site config.

# 2. Configure for static website hosting
aws s3 website "s3://$BUCKET_NAME/" --index-document index.html --profile "$PROFILE"

# 3. Create CloudFront Distribution
echo "Creating CloudFront distribution... This may take a few minutes."
# This is a bit complex via CLI without a JSON file. 
# We'll create a JSON config for the distribution.

cat <<EOF > cloudfront-config.json
{
  "CallerReference": "$(date +%s)",
  "Aliases": {
    "Quantity": 0
  },
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-Origin",
        "DomainName": "$BUCKET_NAME.s3-website-$REGION.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-Origin",
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "ViewerProtocolPolicy": "redirect-to-https",
    "MinTTL": 0
  },
  "CacheBehaviors": {
    "Quantity": 0
  },
  "Comment": "PW50 Static Site Distribution",
  "Enabled": true
}
EOF

DIST_ID=$(aws cloudfront create-distribution --distribution-config file://cloudfront-config.json --profile "$PROFILE" --query 'Distribution.Id' --output text)

echo "Success! Distribution ID: $DIST_ID"
echo "Bucket Name: $BUCKET_NAME"
echo "Saving details to .aws-deploy-info..."

cat <<EOF > .aws-deploy-info
BUCKET_NAME=$BUCKET_NAME
DIST_ID=$DIST_ID
REGION=$REGION
PROFILE=$PROFILE
EOF

# Initial deployment
echo "Running initial sync..."
aws s3 sync . "s3://$BUCKET_NAME/" --exclude ".git/*" --exclude "aws-setup.sh" --exclude "cloudfront-config.json" --exclude ".aws-deploy-info" --profile "$PROFILE"

echo "Deployment complete."
echo "Wait for CloudFront to propagate, then your site will be available at the CloudFront domain."
