# Runbook: S3 bucket exposed to the public

## Triage

Confirm the finding in Security Hub (control S3.8 or S3.2). Check the bucket policy and ACLs
for a Principal of "*" and identify the data classification of the bucket from its tags.

## Containment

Enable S3 Block Public Access at the bucket level immediately. If the account-level setting
is off, turn it on after confirming no approved public website depends on it.

## Prevention

Enforce Block Public Access with a Service Control Policy and fail pull requests where
Checkov reports CKV_AWS_53 to CKV_AWS_56 on new buckets.
