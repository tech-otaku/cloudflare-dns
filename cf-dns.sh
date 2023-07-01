#!/usr/bin/env bash

# AUTHOR: Steve Ward [steve at tech-otaku dot com]
# URL: https://github.com/tech-otaku/cloudflare-dns.git
# README: https://github.com/tech-otaku/cloudflare-dns/blob/main/README.md

# USAGE: ./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED -C COMMENT [-k] [-o]
# EXAMPLE: ./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y -C 'A comment'
#   See the README for more examples



# # # # # # # # # # # # # # # # # # # #
# START-UP CHECKS
#

# Exit with error if Python 3 is not installed
    if [ ! $(command -v python3) ]; then 
        printf "\nERROR: * * * This script requires Python 3. * * *\n"
        exit 1
    fi

# Exit with error if the Cloudflare credentials file doesn't exist
    if [ ! -f ./auth.json ]; then
        printf "\nERROR: * * * The file containing your Cloudflare credentials '%s' doesn't exist. * * *\n" $(pwd)/auth.json
        exit 1
    fi

# Unset all variables
    unset ANSWER APIKEY AUTO COMMENT CONTENT DELETE DNS_ID DOMAIN HEADER_EMAIL HEADER_KEY HEADER_TOKEN EMAIL KEY MODE NAME PAYLOAD OVERRIDE PRIORITY PROXIED RECORD REQUEST_HEADER REQUEST_URL RESPONSE TMPFILE TOKEN TTL TYPE ZONE_ID 



# # # # # # # # # # # # # # # # # # # #
# CONSTANTS
#

EMAIL=$(cat ./auth.json | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['email'])")
KEY=$(cat ./auth.json | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['key'])")
TOKEN=$(cat ./auth.json | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['token'])")



# # # # # # # # # # # # # # # # # # # #
# DEFAULTS
#

HEADER_TOKEN="Bearer $TOKEN"
HEADER_EMAIL=""                 # When using a Cloudlare API token to authenticate, this legacy API key credential is included in the request as an empty X-Auth-Email header (--header 'X-Auth-Email: '), but ultimately ignored by curl
HEADER_KEY=""                   # When using a Cloudlare API token to authenticate, this legacy API key credential is included in the request as an empty X-Auth-Key header (--header 'X-Auth-Key: '), but ultimately ignored by curl
MODE="--silent"
#PRIORITY="5"
#PROXIED="true"
#TTL="1"



# # # # # # # # # # # # # # # # # # # #
# FUNCTION DECLARATIONS
#

# Function to execute when the script terminates
    function tidy_up {
        rm -f $TMPFILE
    }

# Ensure the `tidy_up` function is executed every time the script terminates regardless of exit status
    trap tidy_up EXIT

# Function to display usage help
    function usage {
        cat << EOF
                    
    Syntax: 
    ./$(basename $0) -h
    ./$(basename $0) -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED -C COMMENT [-k] [-s] [-o] [-A]
    ./$(basename $0) -d DOMAIN -n NAME -t TYPE -c CONTENT -Z [-a] [-k] [-s] [-o] 

    Options:
    -a              Auto mode. Do not prompt for user interaction.
    -A              Force add new DNS record. Prompts to overwrite existing DNS record(s) if omitted.
    -c CONTENT      DNS record content. REQUIRED.
    -C COMMENT      Comment about the DNS Record.
    -d DOMAIN       The domain name. REQUIRED.
    -h              This help message.
    -k              Use legacy API key for authentication. API token is used if omitted.
    -l TTL          Time to live for DNS record.
    -n NAME         DNS record name. REQUIRED.
    -o              Override use of NAME.DOMAIN to reference applicable DNS record.
    -p PRIORITY     The priority value for an MX type DNS record. Must be an integer >= 0.
    -S              Show curl's progress meter and error messages. Curl is silent if omitted.
    -t TYPE         DNS record type. Must be one of A, AAAA, CNAME, MX or TXT. REQUIRED.       
    -x PROXIED      Should the DNS record be proxied? Must be one of y, Y, n or N.
    -Z DELETE       Delete a given DNS record.

    Example: ./$(basename $0) -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y -C 'A comment'
    Example: ./$(basename $0) -d example.com -t A -n example.com -c 203.0.113.50 -Z -a

    See https://github.com/tech-otaku/cloudflare-dns/blob/main/README.md for more examples.
    
EOF
    }



# # # # # # # # # # # # # # # # # # # #
# COMMAND-LINE OPTIONS
#

# Exit with error if no command line options given
    if [[ ! $@ =~ ^\-.+ ]]; then
        printf "\nERROR: * * * No options given. * * *\n"
        usage
        exit 1
    fi

# Prevent an option that expects an argument from taking the next option as an argument if its own argument is omitted. i.e. -d -n www 
    while getopts ':aAc:C:d:hkl:n:op:St:x:Z' opt; do
        if [[ $OPTARG =~ ^\-.? ]]; then
            printf "\nERROR: * * * '%s' is not valid argument for option '-%s'\n" $OPTARG $opt
            usage
            exit 1
        fi
    done

# Reset OPTIND so getopts can be called a second time
    OPTIND=1        

# Process command line options
    while getopts ':aAc:C:d:hkl:n:op:St:x:Z' opt; do
        case $opt in
            a)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                AUTO=true
                ;;
            A)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                ADD=true
                ;;
            c)  
                CONTENT=$OPTARG
                ;;
            C) 
                if [[ -z $OPTARG ]]; then
                    COMMENT=" "
                else
                    COMMENT=$OPTARG
                fi
                ;;
            d) 
                DOMAIN=$OPTARG 
                ;;
            h)
                usage
                exit 0
                ;;
            k)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance.
                APIKEY=true
                ;;
            l) 
                TTL=$OPTARG  
                ;;
            n) 
                NAME=$OPTARG
                ;;
            o)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                OVERRIDE=true
                ;;
            p) 
                PRIORITY=$OPTARG
                ;;
            S) 
                MODE="--no-silent" 
                ;;
            t) 
                TYPE=$(echo $OPTARG | tr '[:lower:]' '[:upper:]')
                ;;
            x) 
                PROXIED=$OPTARG
                ;;
            Z)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                DELETE=true
                ;;
            :) 
                printf "\nERROR: * * * Argument missing from '-%s' option * * *\n" $OPTARG
                usage
                exit 1
                ;;
            ?) 
                printf "\nERROR: * * * Invalid option: '-%s' * * *\n" $OPTARG
                usage
                exit 1
                ;;
        esac
    done



# # # # # # # # # # # # # # # # # # # #
# USAGE CHECKS
#

# Domain (-d DOMAIN), Type (-t TYPE), Name (-n NAME) and Content (-c CONTENT) are required for all DNS record types, 
# whether creating a new DNS record (POST request), updating an existing DNS record (PATCH request) or deleting an existing DNS record (DELETE request)

    # Domain (-d DOMAIN) is missing
    if [ -z "$DOMAIN" ] || [[ "$DOMAIN" == -* ]]; then
        printf "\nERROR: * * * No domain was specified. * * *\n"
        usage
        exit 1
    fi

    # Type (-t TYPE) is missing or not handled by this script
    if [ -z "$TYPE" ] || [[ ! $TYPE =~ ^(A|AAAA|CNAME|MX|TXT)$ ]]; then
        printf "\nERROR: * * * DNS record type missing or invalid. * * *\n"
        usage
        exit 1
    fi

    # Name (-n NAME) is missing
    if [ -z "$NAME" ] || [[ "$NAME" == -* ]]; then
        printf "\nERROR: * * * No DNS record name was specified. * * *\n"
        usage
        exit 1
    fi

    # Content (-c CONTENT) is missing
    if [ -z "$CONTENT" ] || [[ "$CONTENT" == -* ]]; then
        printf "\nERROR: * * * No DNS record content was specified. * * *\n"
        usage
        exit 1
    fi

# Depending on the record type and the action being undertaken, certain data passed to the script maybe unnecessary and should not be included in the payload.
# By explicitly unsetting the appropriate variables this data can be excluded from the payload.

    # Priority (-p PRIORITY) is only required for MX rcords and Proxy status (-x PROXIED) is only required for A, AAAA and CNAME records when these record types are being created

        if [ -z "$DELETE" ]; then       # Record is being created or updated

        # Priority (-p PRIORITY) is not necessary
            if [ $TYPE != "MX" ]; then
                if [ ! -z "$PRIORITY" ]; then
                # Exclude from payload
                    unset PRIORITY
                fi
            fi

        # Proxy status (-x PROXIED) is not necessary
            if [[ ! $TYPE =~ ^(A|AAAA|CNAME)$ ]]; then
                if [ ! -z "$PROXIED" ]; then
                # Exclude from payload
                    unset PROXIED       # If omitted, the Cloudflare API will default Proxy Status (-x PROXIED) to false for new MX or TXT records as these record types are not proxiable. Alternatively, use PROXIED="false".
#                    PROXIED="false"    # The Cloudflare API will accept a Proxy Status (-x PROXIED) of false for new MX or TXT records. Note: a Proxy Status (-x PROXIED) of true returns "code 9004, This record type cannot be proxied."
                fi
            fi

        fi

    # Comment (-C COMMENT), Priority (-p PRIORITY), Proxied (-x PROXIED) and TTL (-l TTL) aren't necessary if an existing DNS record is being deleted (DELETE request)

        if [ ! -z "$DELETE" ]; then     # Record is being deleted

        # Comment (-C COMMENT) is not neccesary
            if [ ! -z "$COMMENT" ]; then
            # Exclude from payload
                unset COMMENT
            fi

        # Priority (-p PRIORITY) is not neccesary
            if [ ! -z "$PRIORITY" ]; then
            # Exclude from payload
                unset PRIORITY
            fi

        # Proxy status (-x PROXIED) is not neccesary
            if [ ! -z "$PROXIED" ]; then
            # Exclude from payload
                unset PROXIED
            fi

        # TTL (-l TTL) is not neccesary
            if [ ! -z "$TTL" ]; then
            # Exclude from payload
                unset TTL
            fi

        fi

    # Priority (-p PRIORITY), Proxied (-x PROXIED) and TTL (-l TTL) need to be validated when creating a new DNS record (POST request) or updating an existing DNS record (PATCH request)

    # Priority (-p PRIORITY). If given, must be an integer between 0 and 65535
    # Priority (-p PRIORITY) is required when creating a new MX record, but not when updating an existing one. However, at this point it's not known if this 
    # is a new or existing MX record. Consequently we can't force an error on a missing Priority (-p PRIORITY), but only check the validity of one if it's given.
    # Later, if the script determines this is a new MX record without a Priority (-p PRIORITY) it will add a default value of 10 to the payload. 
        if [ ! -z $PRIORITY ]; then
            if [ $TYPE == "MX" ]; then
                if [[ ! $PRIORITY =~ ^[0-9]*$ ]] || [ $PRIORITY -lt 0 ] || [ $PRIORITY -gt 65535 ] ; then
                    printf "\nERROR: * * * Invalid priority value (%s). Must be an integer between 0 and 65535. * * *\n" $PRIORITY
                    usage
                    exit 1
                fi
            fi
        fi

        
    # Proxy status (-x PROXIED). If omitted for A, AAAA or CNAME records, the Cloudflare API defaults this to 'false' i.e DNS Only.
        if [ ! -z $PROXIED ]; then                              
            if [[ $TYPE =~ ^(A|AAAA|CNAME)$ ]]; then
                if [[ ! $PROXIED =~ ^([yY]|[nN]){1}$ ]]; then
                    printf "\nERROR: * * * Invalid proxied status (%s). Must be one of y, Y, n, or N. * * *\n" $PROXIED
                    usage
                    exit 1
                else
                    PROXIED=$( [[ $PROXIED =~ ^(y|Y)$ ]] && echo "true" || echo "false" )
                fi
            fi   
        fi


    # TTL (-l TTL). The Cloudflare API allows integer values between 60 and 86400 seconds, or 1 for Auto, but on the Cloudflare dashboard only the following values can be entered:
    # Auto (1), 1 min (60), 2 min (120), 5 min (300), 10 min (600), 15 min (900), 30 min (1800), 1 hr (3600), 2 hr (7200), 5 hr (18000), 12 hr (43200), 1 day (86400)
        if [ ! -z $TTL ]; then      # The TTL (-t TTL) need only be validated if a value has been passed to the script. It is not required and is defaulted to Auto (1) by the Cloudflare API if omitted.
            if [[ ! $TTL =~ ^(1|60|120|300|600|900|1800|3600|7200|18000|43200|86400)$ ]]; then
                printf "\nERROR: * * * Invalid TTL value (%s). Must be one of 1, 60, 120, 300, 600, 900, 1800, 3600, 7200, 18000, 43200 or 86400 * * *\n" $TTL
                usage
                exit 1
            fi
        fi



# # # # # # # # # # # # # # # # # # # #
# OVERRIDES
#

# Use legacy API key to authenticate instead of API token
    if [ ! -z "$APIKEY" ]; then
        HEADER_TOKEN=""                 # When using a Cloudlare legacy API key to authenticate, the API token is included in the request as as an empty Authorization header (--header 'Authorization: '), but ultimately ignored by curl
        HEADER_EMAIL="$EMAIL"
        HEADER_KEY="$KEY"
    fi  

# Append domain name to supplied DNS record name. Ensures that all DNS records are managed using their correct naming convention: 'www.example.com' as opposed to 'www' 
#    if [ -z "$OVERRIDE" ]; then                                    # Only if '-o' otion given
        if [[ ! ("$NAME" == *"$DOMAIN"*) ]]; then
            NAME=$NAME.$DOMAIN
        fi
#    fi

# Override TTL (-l TTL). A value other than Auto (1) can only be set if the DNS record's Proxy status (-x PROXIED) is DNS only (false)
    if [ ! -z $TTL ] && [ ! -z $PROXIED ]; then
        if [ $TTL != "1" ] && [ $PROXIED == "true" ]; then
            TTL=1
        fi
    fi

# Comment
    if [[ ! -z $COMMENT ]]; then
    # Replace any double quotes with single quotes. 
        COMMENT=${COMMENT//\"/\'}
    # Truncate comment if it exceeds the maximum number of characters (100) allowed by Cloudflare
        if [ ${#COMMENT} -gt 100 ]; then
            COMMENT=$(echo $COMMENT | cut -c -97)...
        fi
    fi


# # # # # # # # # # # # # # # # # # # #
# ADD | UPDATE | DELETE DNS RECORDS
#

# Get the domain's zone ID
    printf "\nAttempting to get zone ID for domain '%s'\n" $DOMAIN

    ZONE_ID=$(
        curl $MODE -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
        --header "Authorization: $HEADER_TOKEN" \
        --header "X-Auth-Email: $HEADER_EMAIL" \
        --header "X-Auth-Key: $HEADER_KEY" \
        --header "Content-Type: application/json" \
        | python3 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')"
    ) 

    if [ -z "$ZONE_ID" ]; then
        printf "\nABORTING: * * * The domain '%s' doesn't exist on Cloudflare * * *\n" "$DOMAIN"
        exit 1
    else
        printf ">>> %s\n" "$ZONE_ID"
    fi
    
# Get the DNS record's ID based on type, name and content
    printf "\nAttempting to get ID for DNS '%s' record named '%s' whose content is '%s'\n" "$TYPE" "$NAME" "$CONTENT"

    DNS_ID=$(
        curl $MODE -G "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        --data-urlencode "type=$TYPE" \
        --data-urlencode "name=$NAME" \
        --data-urlencode "content=$CONTENT" \
        --header "Authorization: $HEADER_TOKEN" \
        --header "X-Auth-Email: $HEADER_EMAIL" \
        --header "X-Auth-Key: $HEADER_KEY" \
        | python3 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')"
    )

    if [ -z "$DNS_ID" ]; then
        printf ">>> %s\n" "No record found (1)"
    else
        printf ">>> %s\n" "$DNS_ID"
    fi

# Add a new DNS record or update an existing one.
    if [ -z "$DELETE" ]; then

    # If no DNS record was found matching type, name and content look for all DNS records matching only type and name
        if [ -z "$DNS_ID" ]; then

            TMPFILE=$(mktemp)

            printf "\nAttempting to get all DNS records whose type is '%s' named '%s'\n" "$TYPE" "$NAME"
            curl $MODE -G "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            --data-urlencode "type=$TYPE" \
            --data-urlencode "name=$NAME" \
            --header "Authorization: $HEADER_TOKEN" \
            --header "X-Auth-Email: $HEADER_EMAIL" \
            --header "X-Auth-Key: $HEADER_KEY" \
            | python3 -c $'import sys,json\ndata=json.loads(sys.stdin.read())\nif data["success"]:\n\tfor dict in data["result"]:print(dict["id"] + "\t" + dict["type"] + "\t" + dict["name"] + "\t" + dict["content"])\nelse:print("ERROR(" + str(data["errors"][0]["code"]) + "): " + data["errors"][0]["message"])' > $TMPFILE

            if [ $(wc -l < $TMPFILE) -gt 0 ]; then
                printf "\nFound %s existing DNS record(s) whose type is '%s' named '%s'\n" $(wc -l < $TMPFILE) "$TYPE" "$NAME"
                i=0
                while read record; do
                    i=$((i+1))
                    printf '[%s] ID:%s, TYPE:%s, NAME:%s, CONTENT:%s\n' $i "$(printf '%s' "$record" | cut -d$'\t' -f1)" "$(printf '%s' "$record" | cut -d$'\t' -f2)" "$(printf '%s' "$record" | cut -d$'\t' -f3)" "$(printf '%s' "$record" | cut -d$'\t' -f4)"
                done < $TMPFILE
                echo "[A] Add New DNS Record"
                echo -e "[Q] Quit\n"
            
                while true; do
                    read -p "Type $(for((x=1;x<=$i;++x)); do printf "'%s', " $x; done | rev | cut -c3- | sed 's/ ,/ ro /' | rev) to update an existing record, 'A' to add a new record or 'Q' to quit without changes and then press enter: " ANSWER
                    case $ANSWER in
                        [1-$i]) 
                            DNS_ID=$(sed -n $ANSWER'p' < $TMPFILE | cut -d$'\t' -f1 | cut -d$'\t' -f2); 
                            break;;
                        [aA])
                            unset DNS_ID; 
                            break;;
                        [qQ]) 
                            exit
                            ;;
                        *) 
    #                        echo "Please enter a valid option."
                            ;;
                    esac
                done

            else

                printf ">>> %s\n" "No record(s) found (2)"

            fi

        fi

    # Create the payload. 
    # Must always include type, name and content. 
        PAYLOAD="\"type\":\"$TYPE\",\"name\":\"$NAME\",\"content\":\"$CONTENT\""
    # Can optionally include priority, proxied status, ttl and comment 
        PAYLOAD+=$(if [ ! -z $PRIORITY ]; then echo ",\"priority\":$PRIORITY"; fi)
        PAYLOAD+=$(if [ ! -z $PROXIED ]; then echo ",\"proxied\":$PROXIED"; fi)
        PAYLOAD+=$(if [ ! -z $TTL ]; then echo ",\"ttl\":$TTL"; fi)
        PAYLOAD+=$(if [[ ! -z $COMMENT ]]; then echo ",\"comment\":\""$COMMENT"\""; fi)   # Use [[ rather than [ as spaces in comment will throw an error

        if [ -z "$DNS_ID" ]; then
        # DNS record doesn't exist. Create a new one.
            if [ $TYPE == "MX" ] && [ -z $PRIORITY ]; then
            # This is a new MX record without a Priority (-p PRIORITY), so add a default value of 10 to the payload.
                PAYLOAD+=",\"priority\":10"
            fi
            REQUEST_TYPE="POST"
            REQUEST_URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/"
            printf "\nAdding new DNS '%s' record named '%s'\n" $TYPE $NAME
        else
        # DNS record already exists. Update the existing record.
            REQUEST_TYPE="PATCH" 
            REQUEST_URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_ID"
            printf "\nUpdating existing DNS '%s' record named '%s'\n" $TYPE $NAME
        fi

        curl $MODE -X "$REQUEST_TYPE" "$REQUEST_URL" \
        --header "Authorization: $HEADER_TOKEN" \
        --header "X-Auth-Email: $HEADER_EMAIL" \
        --header "X-Auth-Key: $HEADER_KEY" \
        --header "Content-Type: application/json" \
        --data '{'"$PAYLOAD"'}' \
        | python3 -m json.tool --sort-keys

# Delete an existing DNS record
    else

        RECORD=$(printf "DNS '%s' record named '%s' whose content is '%s'" "$TYPE" "$NAME" "$CONTENT")

        if [ -z "$DNS_ID" ]; then
            printf "\nWARNING: * * * No $RECORD exists * * *\n" 
        else
            if [ -z $AUTO ]; then
               read -r -p "$(echo -e '\n'Delete the $RECORD [Y/n]?) " RESPONSE
            else
                RESPONSE=Y
            fi
            
            if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                printf "\nDeleteing the $RECORD\n"      
                curl $MODE -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_ID" \
                --header "Authorization: $HEADER_TOKEN" \
                --header "X-Auth-Email: $HEADER_EMAIL" \
                --header "X-Auth-Key: $HEADER_KEY" \
                --header "Content-Type: application/json" \
                | python3 -m json.tool --sort-keys
            else
                printf "\nThe $RECORD has NOT been deleted.\n"
            fi
        fi
    fi
