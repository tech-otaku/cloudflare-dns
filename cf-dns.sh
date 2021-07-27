#!/usr/bin/env bash

# AUTHOR: Steve Ward [steve at tech-otaku dot com]
# URL: https://github.com/tech-otaku/cloudflare-dns.git
# README: https://github.com/tech-otaku/cloudflare-dns/blob/master/README.md

# USAGE: ./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED [-k] [-o]
# EXAMPLE: ./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y
#   See the README for more examples



# # # # # # # # # # # # # # # # 
# START-UP CHECKS
#

AUTHPATH=./auth.json

# Exit with error if Python 3 is not installed
    if [ ! $(command -v python3) ]; then 
        printf "\nERROR: * * * This script requires Python 3. * * *\n"
        exit -1
    fi

# Exit with error if the Cloudflare credentials file doesn't exist
    if [ ! -f $AUTHPATH ]; then
        printf "\nERROR: * * * The file containing your Cloudflare credentials '%s' doesn't exist. * * *\n" $(pwd)/auth.json
        exit -1
    fi

# Unset all variables
    unset APIKEY AUTH_HEADERS CONTENT DNS_ID DOMAIN EMAIL KEY NAME OVERRIDE PRIORITY PROXIED REQUEST TOKEN TTL TYPE ZONE_ID 



# # # # # # # # # # # # # # # # 
# CONSTANTS
#

EMAIL=$(cat $AUTHPATH | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['email'])")
KEY=$(cat $AUTHPATH | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['key'])")
TOKEN=$(cat $AUTHPATH | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['token'])")           



# # # # # # # # # # # # # # # # 
# DEFAULTS
#

AUTH_HEADERS=( "Authorization: Bearer $TOKEN" )
#PRIORITY="5"
#PROXIED="true"
#TTL="1"



# # # # # # # # # # # # # # # # 
# FUNCTION DECLARATIONS
#

# Function to display usage help
    function usage {
        cat << EOF
                    
    Syntax: 
    ./$(basename $0) -h
    ./$(basename $0) -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED [-k] [-o] 

    Options:
    -c CONTENT      DNS record content. REQUIRED.
    -d DOMAIN       The domain name. REQUIRED.
    -h              This help message.
    -k              Use legacy API key for authentication. API token is used if omitted.
    -l TTL          Time to live for DNS record. Must be an integer >= 1. REQUIRED.
    -n NAME         DNS record name. REQUIRED.
    -o              Override use of NAME.DOMAIN to reference applicable DNS record.
    -p PRIORITY     The priority value for an MX type DNS record. Must be an integer >= 0. REQUIRED for MX type record.
    -t TYPE         DNS record type. Must be one of A, AAAA, CNAME, MX or TXT. REQUIRED.
    -x PROXIED      Should the DNS record be proxied? Must be one of y, Y, n or N. REQUIRED.

    Example: ./$(basename $0) -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y

    See https://github.com/tech-otaku/cloudflare-dns/blob/master/README.md for more examples.
    
EOF
    }



# # # # # # # # # # # # # # # # 
# COMMAND-LINE OPTIONS
#

# Exit with error if no command line options given
    if [[ ! $@ =~ ^\-.+ ]]; then
        printf "\nERROR: * * * No options given. * * *\n"
        usage
        exit 1
    fi

# Prevent an option that expects an argument, taking the next option as an argument if its argument is omitted. i.e. -d -n www -c 
    while getopts ':c:d:hl:n:op:t:x' opt; do
        if [[ $OPTARG =~ ^\-.? ]]; then
            printf "\nERROR: * * * '%s' is not valid argument for option '-%s'\n" $OPTARG $opt
            usage
            exit 1
        fi
    done

# Reset OPTIND so getopts can be called a second time
    OPTIND=1        

# Process command line options
    while getopts ':c:d:hkl:n:op:t:x:' opt; do
        case $opt in
            c) 
                CONTENT=$OPTARG 
                ;;
            d) 
                DOMAIN=$OPTARG 
                ;;
            h)
                usage
                exit 0
                ;;
            k) 
                APIKEY="true"  
                ;;
            l) 
                TTL=$OPTARG  
                ;;
            n) 
                NAME=$OPTARG  
                ;;
            o) 
                OVERRIDE="true"  
                ;;
            p) 
                PRIORITY=$OPTARG  
                ;;
            t) 
                TYPE=$(echo $OPTARG | tr '[:lower:]' '[:upper:]')  
                ;;
            x) 
                PROXIED=$OPTARG  
                ;;
            :) 
                printf "\nERROR: * * * Argument missing from '-%s' option * * *\n" $OPTARG
                usage
                exit 1
                ;;
            ?) 
                printf "\nERROR: * * * Invalid option: '-%s'\n * * * " $OPTARG
                usage
                exit 1
                ;;
        esac
    done



# # # # # # # # # # # # # # # # 
# USAGE CHECKS
#

# DOMAIN is missing
    if [ -z "$DOMAIN" ] || [[ "$DOMAIN" == -* ]]; then
        printf "\nERROR: * * * No domain was specified. * * *\n"
        usage
        exit 1
    fi

# TYPE is missing or not handled by this script
    if [[ ! $TYPE =~ ^(A|AAAA|CNAME|MX|TXT)$ ]]; then
        printf "\nERROR: * * * DNS record type missing or invalid. * * *\n"
        usage
        exit 1
    fi

# NAME is missing
    if [ -z "$NAME" ] || [[ "$NAME" == -* ]]; then
        printf "\nERROR: * * * No DNS record name was specified. * * *\n"
        usage
        exit 1
    fi

# CONTENT is missing
    if [ -z "$CONTENT" ] || [[ "$CONTENT" == -* ]]; then
        printf "\nERROR: * * * No DNS record content was specified. * * *\n"
        usage
        exit 1
    fi

# PROXIED (non-MX or non-TXT records only) is missing or invalid. Must be specified and be one of y, Y, n, or N
    if [[ ! $TYPE =~ ^(MX|TXT)$ ]]; then 
        if [[ ! $PROXIED =~ ^([yY]|[nN]){1}$ ]]; then
            printf "\nERROR: * * * DNS record proxy status missing or invalid. * * *\n"
            usage
            exit 1
        else
            PROXIED=$( [[ $PROXIED =~ ^(y|Y)$ ]] && echo "true" || echo "false" )
        fi
    fi

# TTL is missing or invalid. Must be specified and be an integer >= 1
    if ( [ -z $TTL ] || [[ ! $TTL =~ ^[0-9]*$ ]] || [ ! $TTL -ge 1 ] ); then
        printf "\nERROR: * * * DNS record TTL missing or invalid. * * *\n"
        usage
        exit 1
    fi

# PRIORITY (MX records only) is missing or invalid. Must be specified and be an integer >= 0 
    if [ $TYPE == "MX" ] && ( [ -z $PRIORITY ] || [[ ! $PRIORITY =~ ^[0-9]*$ ]] || [ ! $PRIORITY -ge 0 ] ); then
        printf "\nERROR: * * * DNS record priority missing or invalid. * * *\n"
        usage
        exit 1
    fi



# # # # # # # # # # # # # # # # 
# OVERRIDES
#

# Override 'Proxy status'
    if [ $TTL != "1" ] && [[ $PROXIED != "false" ]]; then
        # A TTL other than "1" can only be set if the DNS record's 'Proxy status' is 'DNS only'  
        PROXIED="false"
    fi

# Use legacy API key to authenticate instead of API token
    if [ ! -z "$APIKEY" ]; then 
        AUTH_HEADERS=( "X-Auth-Email: $EMAIL" "X-Auth-Key: $KEY" )
    fi  

# Append domain name to supplied DNS record name. Ensures that all DNS records are managed using their correct naming convention: 'www.example.com' as opposed to 'www' 
#    if [ -z "$OVERRIDE" ]; then                                    # Only if '-o' otion given
        if [ "$NAME" != "$DOMAIN" ]; then
            NAME=$NAME.$DOMAIN
        fi
#    fi



# # # # # # # # # # # # # # # # 
# ADD | UPDATE DNS RECORDS
#

# Get the domain's zone ID
    printf "\nGetting zone ID for domain '%s'\n" $DOMAIN
    ZONE_ID=\
$(curl -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
        "${AUTH_HEADERS[@]/#/-H}" \
        -H "Content-Type: application/json" \
        | python3 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')"); 

    if [ -z "$ZONE_ID" ]; then
        printf "\nERROR: * * * The domain '%s' doesn't exist on Cloudflare\n * * * " "$DOMAIN"
        exit 1
    fi
    
# Get the DNS record's ID based on type, name and content.
    printf "\nGetting ID for DNS '%s' record named '%s' whose content is '%s'\n" "$TYPE" "$NAME" "$CONTENT"
    DNS_ID=\
$(curl -G -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" --data-urlencode "type=$TYPE" --data-urlencode "name=$NAME" --data-urlencode "content=$CONTENT" \
        "${AUTH_HEADERS[@]/#/-H}" \
        -H "Content-Type: application/json" \
        | python3 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')");

# If no DNS record was found matching type, name and content look for a DNS record matching type and name only
    if [ -z "$DNS_ID" ]; then
        printf "\nGetting ID for DNS '%s' record named '%s'\n" "$TYPE" "$NAME"
        DNS_ID=\
$(curl -G -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" --data-urlencode "type=$TYPE" --data-urlencode "name=$NAME" \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            | python3 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')");
    fi

    if [ -z "$DNS_ID" ]; then
        # DNS record doesn't exist. Create a new one.
        REQUEST=("POST https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/")
        printf "\nAdding new DNS '%s' record named '%s'\n" $TYPE $NAME
    else
        # DNS record already exists. Update existing record.
        REQUEST=("PUT https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_ID")
        printf "\nUpdating existing DNS '%s' record named '%s'\n" $TYPE $NAME
    fi

    if [ $TYPE == "A" ] || [ $TYPE == "AAAA" ] || [ $TYPE == "CNAME" ]; then
        curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","proxied":'"$PROXIED"',"ttl":'"$TTL"'}' \
            | python3 -m json.tool;
    elif [ $TYPE == "MX" ]; then
        curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","priority":'"$PRIORITY"',"ttl":'"$TTL"'}' \
            | python3 -m json.tool;
    else
        curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","ttl":'"$TTL"'}' \
            | python3 -m json.tool;
    fi 
