# Runbook: leaked AWS access key

## Containment

Deactivate the access key first, then delete it after the investigation. Attach a deny-all
inline policy to the IAM user if you suspect other keys or console access.

## Investigation

Query CloudTrail for every API call made with the key ID in the last 90 days. Look for
new IAM users, new access keys, EC2 instances in unused regions and changes to logging.

## Recovery

Rotate any secret the key could read, remove resources the attacker created, and replace
long-lived keys with IAM roles and short-lived credentials.
