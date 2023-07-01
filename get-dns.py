#!/usr/bin/env python3

import argparse, datetime, os, json, sys
from contextlib import redirect_stdout

# Check Python version
if not sys.version_info >= (3, 6):
    print('Python 3.6 or later is required to run this script.')
    sys.exit(1)

try:
    import requests
except ImportError as e:
    print('Please install the \'requests\' library using \'pip install requests\'')
    sys.exit(1)


def get_args():

    parser = argparse.ArgumentParser(description='Get all DNS records for a given domain (-d/--domain)', formatter_class=lambda prog: argparse.HelpFormatter(prog, max_help_position=50))
    parser.add_argument('-d', '--domain', required=True, help='the domain to target')
    parser.add_argument('-k', '--key', action='store_true', help='use legacy API key to authenticate')
    parser.add_argument('-p', '--pretty', action='store_true', help='pretty-print raw JSON data in output (requires -r/--raw)')
    parser.add_argument('-r', '--raw', action='store_true', help='include raw JSON data in output')
    parser.add_argument('-s', '--screen', action='store_true', help='send output to screen')

    return parser.parse_args()

def get_credentials():

    # Attempt to open the file containing the user's Cloudflare credentials 
    try:
        with open('auth.json', 'r', encoding='utf-8') as f:
            return json.load(f)

    except FileNotFoundError as e:
        sys.exit(e)


def set_headers(key, credentials):

    # Define authentication method
    if key:
        # Legacy API key (-k/--key)
        headers = {
            'X-Auth-Email': credentials['cloudflare']['email'],
            'X-Auth-Key': credentials['cloudflare']['key']
        }
    else:
        # API token 
        headers = {
            'Authorization': 'Bearer ' + credentials['cloudflare']['token']
        }

    headers.update({'Content-Type': 'application/json'})

    return headers


def main():

    args = get_args()

    credentials = get_credentials()

    headers = set_headers(args.key, credentials)

#    params={'name': args.domain}


    # Attempt to get the zone ID of the targeted domain
    try:
        response = requests.get('https://api.cloudflare.com/client/v4/zones', params={'name': args.domain}, headers=headers)
        response.raise_for_status()

    except requests.HTTPError as e:     # == requests.exceptions.HTTPError as e:
        # An HTTP error is not raised if the domain doesn't exist on your Cloudflare account. Any HTTP errors are likely due to incorrect Cloudflare credentials: 
            # Legacy API key:
            #     400 if email is invalid (does not contain '@' character or domain part contains non-alphanumeric characters other than '-' )
            #     403 if email is incorrect (doesn't match)
            #     400 if legacy API key is invalid (less than 37 alphnumeric characters or contains upper-case letters, lower-case letters not in the range 'a' to 'f' or non-aplhnumeric characters)
            #     403 if legacy API key is incorrect (doesn't match)
            # API Token
            #     400 if API token is invalid (less than 40 alphanumeric characters or contains non-aplhnumeric characters)
            #     403 if API token is incorrect (doesn't match)

        # The response from the Cloudflare API is serialised JSON content. 
        error_info = response.json()      # == json.loads(response.text)

        if response.status_code == 400:
            # 400 (6003) Invalid request headers, (6102) Invalid format for X-Auth-Email header [Legacy API Key]
            # 400 (6003) Invalid request headers, (6103) Invalid format for X-Auth-Key header [Legacy API Key]
            # 400 (6003) Invalid request headers, (6111) Invalid format for Authorization header [API Token]
            print(f"* * * ERROR: ({str(error_info['errors'][0]['code'])}) {error_info['errors'][0]['message']}, ({str(error_info['errors'][0]['error_chain'][0]['code'])}) {error_info['errors'][0]['error_chain'][0]['message']} * * *")

        elif response.status_code == 403:
            # 403 (9103) Unknown X-Auth-Key or X-Auth-Email [Legacy API Key]
            # 403 (9109) Invalid Access Token [API Token]
            print('* * * ERROR: (' + str(error_info['errors'][0]['code']) +') ' + error_info['errors'][0]['message'] + ' * * *')
            print(f"* * * ERROR: ({str(error_info['errors'][0]['code'])}) {error_info['errors'][0]['message']} * * *")

        else:
            print(f'* * * ERROR: {e} * * *')

        sys.exit()

    # The response from the Cloudflare API is serialised JSON content.
    zone_info = response.json()      # == json.loads(response.text)

    try:
        #The domain's zone ID is stored in the 'id' key of the first [0] element of the 'result' key array (list). If the domain does not exist on your Cloudflare account, the JSON returned contains an empty 'result' key array and attempting to access the 'id' key will raise an 'IndexError' exception.
        zone_id = zone_info['result'][0]['id']
    except IndexError as e:
        sys.exit(e)

    # Now we have the domain's zone ID, we can get all of its DNS records
    response = requests.get('https://api.cloudflare.com/client/v4/zones/' + zone_id + '/dns_records', headers=headers)

    # The response from the Cloudflare API is serialised JSON content.
    dns_records_info = response.json()      # == json.loads(response.text)

    output = f'Generated on {datetime.datetime.now().strftime("%d/%m/%Y")} at {datetime.datetime.now().strftime("%H:%M:%S")}\n\n'

#    for record in dns_records_info['result']:
    for count, record in enumerate(dns_records_info['result'], start=1):

        output += f'Record: {str(count)}/{str(len(dns_records_info["result"]))}\n\n'
  
        if args.raw:
            # Include raw JSON in output (-r/--raw)

            indent=None
            if args.pretty:
#                indent='\t'
                indent=2

            # Serialise 
            output += json.dumps(record, sort_keys=True, indent=indent) + '\n\n'

        """
        Available keys for 'record'
            comment
            content
            created_on
            id
            locked
            meta {
                auto_added
                managed_by_apps
                managed_by_argo_tunnel
                source
            }
            modified_on
            name
            priority      'MX' records only
            proxiable
            proxied
            ttl
            type
            zone_id
            zone_name
        """

        domain = record['zone_name']
        record_type = record['type']
        name = record['name']
        content = record['content']
        if 'priority' in record:                    # 'record' contains the 'priority' key
            priority = str(record['priority'])
        proxiable = str(record['proxiable'])
        proxied = str(record['proxied'])
        ttl = str(record['ttl'])
        modified = record['modified_on']
        comment=''
        if record['comment'] is not None:
            comment = record['comment']

        output += f'Domain: {domain}\nType: {record_type}\nName: {name}\nContent: {content}\n' + (f'Priority: {priority}\n' if 'priority' in record else '') + f'Proxiable: {proxiable}\nProxied: {proxied}\nTTL: {ttl}\nComment: {comment}\nModified: {modified}\n'

        if record_type.upper() in ('A','AAAA','CNAME','MX','TXT'):

            if f'.{domain}' in name:
                # Remove '.domain' from 'name' e.g 'dkim._domainkey.example.com' should be passed as 'dkim._domainkey' to cf-dns.sh
                name = name.replace(f'.{domain}', '')

            if record_type.upper() in 'TXT':
                # Enclose 'content' in quotes to deal with characters it may contain that would otherwise need to be escaped 
                content = f'\'{content}\''

            if proxiable.lower() in 'true':
                if proxied.lower() in 'true':
                    proxied = 'Y'

                if proxied.lower() in 'false':
                    proxied = 'N'

#            if comment in 'none':

#            comment = comment.replace('None', '')
            if comment:
                comment = f'\'{comment}\''
#            comment = f'\'{comment.replace("on", "")}\''
#            comment = comment.replace("on", "")

            output += f'./cf-dns.sh -d {domain} -t {record_type} -n {name} -c {content}' + (f' -p {priority}' if record_type.upper() in 'MX' else '') + (f' -x {proxied}' if proxiable.lower() in 'true' else '') + f' -l {ttl}' + (f' -C {comment}' if comment else '') + ' [-k] [-S] [-A]\n'

            output += f'./cf-dns.sh -d {domain} -t {record_type} -n {name} -c {content} -Z [-a] [-k] [-S]\n\n'

            output += '* ' * 50 + '\n'
        
        else:

            output += f'* * * Type \'{record_type}\' records are not handled by the script: cf-dns.sh * * *\n\n'

    if args.screen:
        # Send output to screen
        print(output)
    else:
        # Redirect output to a newly created file (default) if the user hasn't chosen to display output to screen (-s/--screen)
        with open(os.environ['HOME'] + '/' + args.domain + '-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')[:-3] + '.txt', 'w') as f:
            with redirect_stdout(f):
                print(output)

        print(f'Output written to {f.name}')

if __name__== '__main__' :
    main()