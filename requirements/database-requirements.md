# Database Credentials

## MySQL Root Password
- **Current password**: "my-secret-pw"
- This is configured in:
  - `kubernetes/secrets.yaml` (base64 encoded as "bXktc2VjcmV0LXB3")
  - Used in database container initialization

## Changing the Password
1. **Encode your new password**:
   ```
   echo -n 'your-new-password' | base64
   ```

2. **Update the following files**:
   - `kubernetes/secrets.yaml`: Replace the base64 encoded password
   - `stress-test/run-load-test.sh`: Update the DB_PASSWORD variable
   - `deploy.sh`: Update the DB_PASSWORD variable

## Additional Database Settings
- **Database name**: real_estate_calls_db
- **Database host** (internal to Kubernetes): db-service
- **Database port**: 3306
