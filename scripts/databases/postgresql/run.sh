# Start of block Set a password for the infranettone database user.
echo -e "${CYAN}Start of block Set a password for the infranettone database user.${NC}"
generate_strong_password() {
    local generated_password
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ OpenSSL is required to generate an automatic password." >&2
        return 1
    fi
    while true; do
        generated_password=$(openssl rand -base64 48)
        if [[ "$generated_password" =~ [A-Z] && "$generated_password" =~ [a-z] && "$generated_password" =~ [0-9] && "$generated_password" =~ [\!\@\#\%\^\*\_\=\+\.\-] ]]; then
            echo "$generated_password"
            return 0
        fi
    done
}

echo "Choose how you want to set the password for the user infranettone:"
select INFRANETTONE_PASSWORD_MODE in "Set manually" "Generate automatically"; do
    case "$INFRANETTONE_PASSWORD_MODE" in
        "Set manually")
            while true; do
                read -s -p "Enter the password for the user infranettone: " INFRANETTONE_PASSWORD
                echo
                read -s -p "Confirm the password for the user infranettone: " INFRANETTONE_PASSWORD_CONFIRM
                echo

                if [[ -z "$INFRANETTONE_PASSWORD" ]]; then
                    echo "❌ The password cannot be empty."
                    continue
                fi

                if [[ "$INFRANETTONE_PASSWORD" == "$INFRANETTONE_PASSWORD_CONFIRM" ]]; then
                    echo "Password confirmed. Continuing..."
                    break
                else
                    echo "Passwords do not match. Please try again."
                fi
            done
            break
            ;;
        "Generate automatically")
            INFRANETTONE_PASSWORD=$(generate_strong_password)
            echo "A strong password was generated automatically."
            break
            ;;
        *)
            echo "Invalid option, please select 1 or 2."
            ;;
    esac
done
echo -e "${CYAN}End of block Set a password for the infranettone database user.${NC}"
# End of block Set a password for the infranettone database user.

# Start of block Create and configure PostgreSQL database.
echo -e "${CYAN}Start of block Create and configure PostgreSQL database.${NC}"
POSTGRES_CONNECTION_PASSWORD="${POSTGRES_PASSWORD:-${POSTGRES_REMOTE_PASSWORD:-}}"
if [[ -z "${POSTGRES_CONNECTION_PASSWORD}" ]]; then
  echo "⚠️ POSTGRES_PASSWORD is not set. Trying connection without password."
fi
docker run --rm \
  -i \
  -e PGPASSWORD="${POSTGRES_CONNECTION_PASSWORD}" \
  -e INFRANETTONE_PASSWORD="${INFRANETTONE_PASSWORD}" \
  alpine/psql:latest \
  -h "$PUBLIC_IP" \
  -U postgres \
  -v ON_ERROR_STOP=1 \
  -v INFRANETTONE_PASSWORD="${INFRANETTONE_PASSWORD}" <<'EOF'

SELECT format('CREATE USER %I WITH PASSWORD %L', 'infranettone', :'INFRANETTONE_PASSWORD')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'infranettone')
\gexec

SELECT format('ALTER USER %I WITH PASSWORD %L', 'infranettone', :'INFRANETTONE_PASSWORD')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'infranettone')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', 'infranettone', 'infranettone')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'infranettone')
\gexec

GRANT ALL PRIVILEGES ON DATABASE infranettone TO infranettone;

\connect infranettone

SELECT format('CREATE SCHEMA %I AUTHORIZATION %I', 'infranettone', 'infranettone')
WHERE NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'infranettone')
\gexec

GRANT ALL ON SCHEMA infranettone TO infranettone;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA infranettone TO infranettone;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA infranettone TO infranettone;
ALTER DEFAULT PRIVILEGES IN SCHEMA infranettone
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO infranettone;
ALTER DEFAULT PRIVILEGES IN SCHEMA infranettone
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO infranettone;

CREATE TABLE IF NOT EXISTS infranettone.projects (
    project_id VARCHAR(255) PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS infranettone.clients (
    client_id VARCHAR(255) PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS infranettone.projects_clients (
    project_id VARCHAR(255) NOT NULL,
    client_id VARCHAR(255) NOT NULL,
    PRIMARY KEY (project_id, client_id),
    CONSTRAINT fk_projects_clients_project
        FOREIGN KEY (project_id)
        REFERENCES infranettone.projects (project_id),
    CONSTRAINT fk_projects_clients_client
        FOREIGN KEY (client_id)
        REFERENCES infranettone.clients (client_id)
);

INSERT INTO infranettone.projects (project_id)
VALUES
    ('project_test_1'),
    ('project_test_2')
ON CONFLICT (project_id) DO NOTHING;

INSERT INTO infranettone.clients (client_id)
VALUES
    ('client_test_1'),
    ('client_test_2'),
    ('client_test_3'),
    ('client_test_4')
ON CONFLICT (client_id) DO NOTHING;

INSERT INTO infranettone.projects_clients (project_id, client_id)
VALUES
    ('project_test_1', 'client_test_1'),
    ('project_test_1', 'client_test_2'),
    ('project_test_1', 'client_test_3'),
    ('project_test_1', 'client_test_4'),
    ('project_test_2', 'client_test_1'),
    ('project_test_2', 'client_test_2'),
    ('project_test_2', 'client_test_3'),
    ('project_test_2', 'client_test_4')
ON CONFLICT (project_id, client_id) DO NOTHING;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA infranettone TO infranettone;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA infranettone TO infranettone;
EOF
echo -e "${CYAN}End of block Create and configure PostgreSQL database.${NC}"
# End of block Create and configure PostgreSQL database.

if [[ "$INFRANETTONE_PASSWORD_MODE" == "Generate automatically" ]]; then
  export PENDING_SECRET_INFRANETTONE_USER_PASSWORD="$INFRANETTONE_PASSWORD"
  echo "Automatic password prepared. The secret will be created from the main script."
fi
