# QWC Admin GUI - Credentials and User Management

This document explains how to access the Admin GUI, what the default credentials are, and how to configure or change them.

## Table of Contents

1. [Default Credentials](#default-credentials)
2. [Accessing Admin GUI](#accessing-admin-gui)
3. [Creating Users](#creating-users)
4. [Changing Passwords](#changing-passwords)
5. [User Roles and Permissions](#user-roles-and-permissions)
6. [Troubleshooting](#troubleshooting)
7. [Security best practices](#security-best-practices)
8. [Quick reference](#quick-reference)

---

## Default Credentials

### Demo Credentials (After Running init-demo-data.sh)

If you've initialized demo data using the `init-demo-data.sh` script, the following users are available:

| Username | Password | Role | Purpose |
| ---------- | ---------- | ------ | --------- |
| `admin` | `demo` | `admin` | Full administrative access |
| `demo` | `demo` | `user` | Regular user access |

**⚠️ Security Warning:** These are **demo credentials** for testing only. **Change them immediately in production!**

---

## Accessing Admin GUI

### Via HTTPRoute (Recommended)

1. **URL:** `https://myhostname.com/admin/`
2. **Login:** Use the credentials from the table above
3. **Browser:** Ensure cookies are enabled (JWT tokens are stored in cookies)

### Via Port Forwarding

If HTTPRoute is not configured, use port-forwarding:

```bash
# Port-forward admin GUI service
kubectl port-forward -n qwc-dev svc/my-qwc-instance-qwcadmingui 8081:80

# Access in browser
# http://localhost:8081/admin/
```

---

## Creating Users

### Method 1: Using init-demo-data.sh Script (Recommended)

The `init-demo-data.sh` script automatically creates demo users:

```bash
# Run from project root - interactive mode
./scripts/init-demo-data.sh

# Or with namespace specified
./scripts/init-demo-data.sh -n qwc-dev
```

**What it creates:**

- Admin user: `admin` / `demo`
- Regular user: `demo` / `demo`
- Admin role assignment
- Demo group

**Options:**

- `-n, --namespace NS`: Kubernetes namespace
- `--skip-users`: Skip user creation
- `--skip-geodata`: Skip demo data creation
- `-y, --yes`: Non-interactive mode (use defaults)

### Method 2: Manual SQL Creation

Connect to the database and create users manually:

```bash
# Get database pod name
DB_POD=$(kubectl get pods -n qwc-dev -l app.kubernetes.io/name=qwcdb -o jsonpath='{.items[0].metadata.name}')

# Connect to database
kubectl exec -it -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services
```

Then execute:

```sql
-- Create admin user
INSERT INTO qwc_users.users (username, email, name, password_hash, active)
VALUES ('admin', 'admin@example.com', 'Administrator',
        crypt('your_secure_password', gen_salt('bf')), true)
ON CONFLICT (username) DO UPDATE
SET password_hash = crypt('your_secure_password', gen_salt('bf')),
    active = true;

-- Assign admin role
INSERT INTO qwc_users.user_roles (username, role_name)
VALUES ('admin', 'admin')
ON CONFLICT (username, role_name) DO NOTHING;

-- Create regular user
INSERT INTO qwc_users.users (username, email, name, password_hash, active)
VALUES ('user1', 'user1@example.com', 'Regular User',
        crypt('user_password', gen_salt('bf')), true)
ON CONFLICT (username) DO UPDATE
SET password_hash = crypt('user_password', gen_salt('bf')),
    active = true;
```

### Method 3: Via Admin GUI (After First Login)

Once logged in as admin:

1. Navigate to **Users** section
2. Click **Add User** or **New User**
3. Fill in:
   - Username
   - Email
   - Name
   - Password
   - Active status
4. Assign roles and groups
5. Save

---

## Changing Passwords

### Method 1: Via Admin GUI

1. Login as admin
2. Go to **Users** section
3. Select the user
4. Click **Edit**
5. Change password
6. Save

### Method 2: Via SQL

```bash
# Connect to database
kubectl exec -it -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services
```

```sql
-- Change password for a user
UPDATE qwc_users.users
SET password_hash = crypt('new_password', gen_salt('bf'))
WHERE username = 'admin';

-- Verify change
SELECT username, email, active FROM qwc_users.users WHERE username = 'admin';
```

### Method 3: Reset Admin Password Script

Create a script to reset admin password:

```bash
#!/bin/bash
# reset-admin-password.sh

DB_POD=$(kubectl get pods -n qwc-dev -l app.kubernetes.io/name=qwcdb -o jsonpath='{.items[0].metadata.name}')
NEW_PASSWORD="${1:-admin123}"

kubectl exec -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services -c "
UPDATE qwc_users.users
SET password_hash = crypt('$NEW_PASSWORD', gen_salt('bf'))
WHERE username = 'admin';
"

echo "Admin password changed to: $NEW_PASSWORD"
```

Usage:

```bash
chmod +x reset-admin-password.sh
./reset-admin-password.sh "my_secure_password"
```

---

## User Roles and Permissions

### Available Roles

| Role | Description | Permissions |
| ------ | ------------- | ------------- |
| `admin` | Administrator | Full access to all features, user management, configuration |
| `user` | Regular user | Access to map viewer, limited features |
| `editor` | Content editor | Can edit some content, limited admin access |

### Role Assignment

Roles are stored in `qwc_users.user_roles` table:

```sql
-- View all user roles
SELECT u.username, u.email, r.role_name
FROM qwc_users.users u
LEFT JOIN qwc_users.user_roles r ON u.username = r.username
ORDER BY u.username;

-- Assign role to user
INSERT INTO qwc_users.user_roles (username, role_name)
VALUES ('username', 'admin')
ON CONFLICT (username, role_name) DO NOTHING;

-- Remove role from user
DELETE FROM qwc_users.user_roles
WHERE username = 'username' AND role_name = 'admin';
```

### Groups

Users can be organized into groups for easier permission management:

```sql
-- View groups
SELECT * FROM qwc_users.groups;

-- Add user to group
INSERT INTO qwc_users.user_groups (username, group_name)
VALUES ('username', 'group_name')
ON CONFLICT (username, group_name) DO NOTHING;
```

---

## Database Schema

Users are stored in the `qwc_users` schema:

### Tables

- **`qwc_users.users`**: User accounts
  - `username` (PK): Unique username
  - `email`: User email
  - `name`: Display name
  - `password_hash`: Bcrypt hashed password
  - `active`: Account status (true/false)

- **`qwc_users.user_roles`**: Role assignments
  - `username` (FK): References users.username
  - `role_name`: Role name (e.g., 'admin')

- **`qwc_users.groups`**: User groups
  - `name` (PK): Group name
  - `description`: Group description
  - `active`: Group status

- **`qwc_users.user_groups`**: User-group memberships
  - `username` (FK): References users.username
  - `group_name` (FK): References groups.name

### Password Hashing

Passwords are hashed using PostgreSQL's `crypt()` function with bcrypt:

```sql
-- Hash password
SELECT crypt('password', gen_salt('bf'));

-- Verify password (in application)
SELECT (password_hash = crypt('entered_password', password_hash)) AS password_match
FROM qwc_users.users
WHERE username = 'admin';
```

---

## Configuration

### Database Connection

The Admin GUI connects to the database using credentials from `pg_service.conf`:

**Location in pods:** `/qwc_cfg/pg_service.conf`

**Service name:** `qwc_configdb`

**Configuration in values.yaml:**

```yaml
qwcAdminGUI:
  pgServiceConfSecret:
    name: my-qwc-instance-global-secret
    key: pg_service_ro.conf
```

### Authentication Settings

Authentication behavior can be configured via environment variables:

```yaml
qwcAdminGUI:
  env:
    # Enable secure cookies (requires HTTPS)
    jwtCookieSecure: true
    jwtCookieSamesite: "Strict"

    # User registration
    groupRegistrationEnabled: false

    # Custom user fields
    userInfoFields: '[{"title": "Surname", "name": "surname", "type": "text"}]'
```

---

## Troubleshooting

### Cannot Login

**Problem:** Login fails with "Invalid credentials"

**Solutions:**

1. **Verify user exists:**

   ```bash
   kubectl exec -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services -c \
     "SELECT username, active FROM qwc_users.users WHERE username = 'admin';"
   ```

2. **Check if user is active:**

   ```sql
   UPDATE qwc_users.users SET active = true WHERE username = 'admin';
   ```

3. **Reset password:**

   ```sql
   UPDATE qwc_users.users
   SET password_hash = crypt('demo', gen_salt('bf'))
   WHERE username = 'admin';
   ```

4. **Check admin role:**

   ```sql
   SELECT * FROM qwc_users.user_roles WHERE username = 'admin';
   ```

### Internal Server Error After Login

**Problem:** Admin GUI shows "Internal Server Error" after successful login

**Cause:** Missing `adminGuiConfig.json` file in config-generated volume

**Solution:** Ensure config-service has generated the configuration:

```bash
# Check config-service logs
kubectl logs -n qwc-dev -l app.kubernetes.io/name=qwcconfigservice --tail=50

# Verify config file exists
kubectl exec -n qwc-dev $CONFIG_POD -- ls -la /qwc_cfg/config-generated/default/adminGuiConfig.json
```

### User Not Found

**Problem:** User exists in database but cannot login

**Solutions:**

1. **Check database connection:**

   ```bash
   kubectl logs -n qwc-dev -l app.kubernetes.io/name=qwcauthservice --tail=50
   ```

2. **Verify pg_service.conf:**

   ```bash
   kubectl exec -n qwc-dev $AUTH_POD -- cat /qwc_cfg/pg_service.conf
   ```

3. **Test database connection from auth service:**

   ```bash
   kubectl exec -n qwc-dev $AUTH_POD -- \
     psql "service=qwc_configdb" -c "SELECT 1;"
   ```

### Password Reset

**Quick reset script:**

```bash
#!/bin/bash
# reset-password.sh <username> <new_password>

USERNAME="${1:-admin}"
NEW_PASSWORD="${2:-demo}"
NAMESPACE="${QWC_NAMESPACE:-qwc-dev}"

DB_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=qwcdb -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NAMESPACE $DB_POD -- psql -U qwc_admin -d qwc_services -c "
UPDATE qwc_users.users
SET password_hash = crypt('$NEW_PASSWORD', gen_salt('bf'))
WHERE username = '$USERNAME';
"

echo "Password for user '$USERNAME' has been reset to: $NEW_PASSWORD"
```

---

## Security Best Practices

### Production Deployment

1. **Change default passwords immediately:**

   ```sql
   UPDATE qwc_users.users
   SET password_hash = crypt('strong_secure_password', gen_salt('bf'))
   WHERE username = 'admin';
   ```

2. **Enable secure cookies (HTTPS required):**

   ```yaml
   qwcAdminGUI:
     env:
       jwtCookieSecure: true
       jwtCookieSamesite: "Strict"
   ```

3. **Use strong passwords:**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Avoid common words

4. **Regular password rotation:**
   - Set password expiration policies
   - Regularly audit user accounts
   - Remove inactive users

5. **Limit admin access:**
   - Only grant admin role to trusted users
   - Use regular user accounts for daily operations
   - Monitor admin actions

6. **Database security:**
   - Use strong database passwords (set in `values.yaml`)
   - Enable SSL for database connections in production
   - Restrict database access to necessary services only

---

## Quick Reference

### Default Demo Credentials

- **Admin:** `admin` / `demo`
- **User:** `demo` / `demo`

### Database Admin Credentials

- **Username:** `qwc_admin` (from `global.db.secrets.qwcAdminPassword`)
- **Password:** Set in `values.yaml` → `global.db.secrets.qwcAdminPassword`

### Access URLs

- **Via HTTPRoute:** `https://myhostname.com/admin/`
- **Via Port-Forward:** `http://localhost:8081/admin/`

### Useful Commands

**Using manage-users.sh script (Recommended):**

```bash
# List all users
./scripts/manage-users.sh list

# Create new user
./scripts/manage-users.sh create admin

# Reset password
./scripts/manage-users.sh reset-password admin

# Set password (non-interactive)
./scripts/manage-users.sh set-password admin newpassword123

# Assign admin role
./scripts/manage-users.sh assign-role admin admin

# Show user details
./scripts/manage-users.sh show admin

# See all commands
./scripts/manage-users.sh
```

**Direct SQL commands:**

```bash
# List all users
kubectl exec -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services -c \
  "SELECT username, email, active FROM qwc_users.users;"

# Check user roles
kubectl exec -n qwc-dev $DB_POD -- psql -U qwc_admin -d qwc_services -c \
  "SELECT u.username, r.role_name FROM qwc_users.users u \
   LEFT JOIN qwc_users.user_roles r ON u.username = r.username;"

# Create user via init script
./scripts/init-demo-data.sh --host my-qwc-instance-qwcdb --admin-pass qwc_admin
```
