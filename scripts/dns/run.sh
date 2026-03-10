# Start of block Would you like to create a DNS record?
echo -e "${CYAN}Start of block Would you like to create a DNS record?${NC}"
echo -e "${YELLOW}Would you like to create a DNS record?${NC}"
select CREATE_DNS_RECORD in "Yes" "No"; do
    case $CREATE_DNS_RECORD in
        "Yes")
            echo "Creating a DNS record..."
            break
            ;;
        "No")
            echo "The DNS record will not be created."
            break
            ;;
        *)
            echo "Invalid option, please select 1 or 2."
            ;;
    esac
done
echo -e "${GREEN}End of block Would you like to create a DNS record?${NC}"
# End of block Would you like to create a DNS record?

# Start of block If the user wants to create a DNS record, ask for the necessary information and create it.
echo -e "${CYAN}Start of block If the user wants to create a DNS record, ask for the necessary information and create it.${NC}"
if [[ "$CREATE_DNS_RECORD" == "Yes" ]]; then
    while true; do
        read -p "Enter the domain name: " DOMAIN_NAME

        echo
        echo -e "${YELLOW}You entered the name:${NC} ${DOMAIN_NAME}"
        echo -e "${YELLOW}Is it correct?${NC}"

        select yn in "Yes" "No"; do
            case $yn in
                "Yes")
                    echo "Continuing..."
                    export DOMAIN_NAME
                    break 2   # exit the select yn and the while loop for the domain
                    ;;
                "No")
                    echo "Okay, let's re-enter the name."
                    break     # exit only the select yn
                    ;;
                *)
                    echo "Invalid option, please select 1 or 2."
                    ;;
            esac
        done
    done

    echo "Creating DNS record..."
    # Here you would add the command to create the DNS record using the AWS CLI or another method
fi
echo -e "${CYAN}End of block If the user wants to create a DNS record, ask for the necessary information and create it.${NC}"
# End of block If the user wants to create a DNS record, ask for the necessary information and create it.

# Start of block If the user wants to create a DNS record and has provided a domain name, create the DNS record pointing to the public IP.
echo -e "${CYAN}Start of block If the user wants to create a DNS record and has provided a domain name, create the DNS record pointing to the public IP.${NC}"
if [[ "$CREATE_DNS_RECORD" == "Yes" && -n "${DOMAIN_NAME:-}" ]]; then
    DNS_RECORD_CREATED="false"
    # Start of block Select your DNS provider that is a folder inside scripts/dns. Do a bash select inside this folder
    echo -e "${CYAN}Start of block Select your DNS provider that is a folder inside scripts/dns. Do a bash select inside this folder${NC}"
    BASE_DOMAIN=$(awk -F. '{print $(NF-1)"."$NF}' <<< "$DOMAIN_NAME")
    echo "BASE_DOMAIN=${BASE_DOMAIN}"
    select DNS_PROVIDER in $(ls -d scripts/dns/*/ | xargs -n 1 basename); do
        case $DNS_PROVIDER in
            "arsys")
                while true; do
                    read -r -s -p "Enter Arsys API key (hidden input): " ARSYS_APIKEY
                    echo
                    if [[ -n "${ARSYS_APIKEY}" ]]; then
                        break
                    fi
                    echo "API key cannot be empty. Please try again."
                done
                echo "Creating a DNS record with the DNS provider arsys for ${DOMAIN_NAME} pointing to ${PUBLIC_IP}..."
                bash scripts/dns/arsys/run.sh \
                --login "${BASE_DOMAIN}" \
                --apikey "${ARSYS_APIKEY}" \
                --domain "${BASE_DOMAIN}" \
                --dns "${DOMAIN_NAME}" \
                --type "A" \
                --value "${PUBLIC_IP}"
                DNS_RECORD_CREATED="true"
                unset ARSYS_APIKEY
                break
                ;;
            *)
                echo "Selected DNS provider: $DNS_PROVIDER"
                break
                ;;
        esac
    done
    echo -e "${GREEN}End of block Select your DNS provider that is a folder inside scripts/dns. Do a bash select inside this folder${NC}"
    # End of block Select your DNS provider that is a folder inside scripts/dns. Do a bash select inside this folder.

    # Start of block Ensure that the DNS has propagated by checking if the domain resolves to the public IP. Use dig or getent in a loop with a timeout.
    echo -e "${CYAN}Start of block Ensure that the DNS has propagated by checking if the domain resolves to the public IP. Use dig or getent in a loop with a timeout.${NC}"
    if [[ "${DNS_RECORD_CREATED}" == "true" ]]; then
        echo -e "${CYAN}Checking DNS propagation for ${DOMAIN_NAME}...${NC}"
        DNS_PROPAGATED="false"
        DNS_MAX_ATTEMPTS=24
        DNS_SLEEP_SECONDS=5
        TARGET_PUBLIC_IP="$(tr -d '\r' <<< "${PUBLIC_IP}" | xargs)"
        TARGET_DOMAIN_NAME="$(tr -d '\r' <<< "${DOMAIN_NAME}" | xargs)"

        for ((attempt=1; attempt<=DNS_MAX_ATTEMPTS; attempt++)); do
            RESOLVED_IPS="$(
                {
                    if command -v dig >/dev/null 2>&1; then
                        # Try system resolver first, then a public resolver as a fallback.
                        dig +short "${TARGET_DOMAIN_NAME}" A 2>/dev/null || true
                        dig +short "${TARGET_DOMAIN_NAME}" A @1.1.1.1 2>/dev/null || true
                    fi
                    getent ahostsv4 "${TARGET_DOMAIN_NAME}" 2>/dev/null | awk '{print $1}' || true
                } \
                    | tr -d '\r' \
                    | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/' \
                    | sort -u
            )"

            if grep -Fxq "${TARGET_PUBLIC_IP}" <<< "${RESOLVED_IPS}"; then
                DNS_PROPAGATED="true"
                echo -e "${GREEN}DNS propagated successfully: ${TARGET_DOMAIN_NAME} -> ${TARGET_PUBLIC_IP}${NC}"
                break
            fi

            if (( attempt < DNS_MAX_ATTEMPTS )); then
                echo "Waiting for propagation (${attempt}/${DNS_MAX_ATTEMPTS})..."
                sleep "${DNS_SLEEP_SECONDS}"
            fi
        done

        if [[ "${DNS_PROPAGATED}" != "true" ]]; then
            echo -e "${YELLOW}DNS record was created but propagation is not confirmed yet for ${DOMAIN_NAME}. Current resolution:${NC}"
            if [[ -n "${RESOLVED_IPS:-}" ]]; then
                echo "${RESOLVED_IPS}"
            else
                echo "No A records resolved yet."
            fi
        fi
    fi
    echo -e "${GREEN}End of block Ensure that the DNS has propagated by checking if the domain resolves to the public IP. Use dig or getent in a loop with a timeout.${NC}"
    # End of block If the user wants to create a DNS record and has provided a domain name, create the DNS record pointing to the public IP.
fi
echo -e "${CYAN}End of block If the user wants to create a DNS record and has provided a domain name, create the DNS record pointing to the public IP.${NC}"
# End of block If the user wants to create a DNS record and has provided a domain name, create the DNS record pointing to the public IP.
