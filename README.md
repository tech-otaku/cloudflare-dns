# cloudflare-dns

## Purpose
Add, update or delete your domain's DNS records from the command line using the [Cloudflare API](https://api.cloudflare.com/#dns-records-for-a-zone-properties). 

## Background
I initially wrote this script as a quick way of repeatedly adding or updating DNS records for several domains from the command line when I was building and testing my mail server. ***If you're thinking of using it, it's important you read the [Limitations](#limitations) section first*** and check your domain's DNS records on Cloudflare afterwards. 

The script is based upon examples of using the Cloudflare API at [Using the Cloudflare API to Manage DNS Records](https://www.tech-otaku.com/web-development/using-cloudflare-api-manage-dns-records/).

To view an existing domain's current DNS records see [Get an Existing Domain's Current DNS Records](#get-an-existing-domains-current-dns-records)

## Usage
#### Help
`./cf-dns.sh -h`

#### Add or Update
`./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT [-p PRIORITY] [-x PROXIED] [-l TTL] [-C COMMENT] [-k] [-S] [-A]`

#### Delete
`./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -Z [-a] [-k] [-S]`

## Options

Use `./cf-dns.sh -h` to see an explanation of the options and their usage.

In addition, please note the following:

---

- The scipt always requires the options *domain* (`-d DOMAIN `), *type* (`-t TYPE`), *name* (`-n NAME`) and *content* (`-c CONTENT`).

- For new MX records, *priority* (`-p PRIORITY`) is required, but will be defaulted to `10` by the script if omitted.

- When updating existing records the script now uses the `PATCH` method of the Cloudflare API instead of `PUT` meaning that, in addition to the mandatory options, **only** the data being updated need be passed to the script. 

- *Proxy status* (`-x PROXIED`) is not required for `MX` or `TXT` records as these DNS record types can not be proxied through Cloudflare. When creating `A`, `AAAA` or `CNAME` records, the Cloudflare API defaults the *proxy status* to `false` if omitted.

- *TTL* (`-l TTL`) can only be set to one of the following values:

    | `-l TTL` | TTL        |
    |----------|------------|
    | `1`      | Auto       |
    | `60`     | 1 minute   |
    | `120`    | 2 minutes  |
    | `300`    | 5 minutes  |
    | `600`    | 10 minutes |
    | `900`    | 15 minutes |
    | `1800`   | 30 minutes |
    | `3600`   | 1 hour     |
    | `7200`   | 2 hours    |
    | `18000`  | 5 hours    |
    | `43200`  | 12 hours   |
    | `86400`  | 1 day      |

    If a DNS record's **Proxy status** (`-x PROXIED`) is _Proxied_ (`true`), its TTL will be set to `1` automtically by the Cloudflare API regardless of the value passed to the script. This is due to Cloudflare only allowing TTL values other than `1` for DNS records that are not proxied.

- The script checks if the domain name (`-d DOMAIN`) and DNS record name (`-n NAME`) are the same. If not, the domain name is appended to the DNS record name as per the table below (think `dig TXT example.com` and `dig TXT dkim._domainkey.example.com`).

    | TYPE  | DOMAIN      | NAME                | REFERENCED AS                   |
    |:------|:------------|:--------------------|:--------------------------------|
    | A     | example.com | **example.com**     | example.com                     |
    | AAAA  | example.com | **example.com**     | example.com                     |
    | A     | example.com | **demo**            | **demo**.example.com            |
    | CNAME | example.com | **www**             | **www**.example.com             |
    | MX    | example.com | **example.com**     | example.com                     |
    | TXT   | example.com | **dkim._domainkey** | **dkim._domainkey**.example.com |
    | TXT   | example.com | **_dmarc**          | **_dmarc**.example.com          |
    | TXT   | example.com | **example.com**     | example.com                     |

    <br />  

- Strings containing spaces must be enclosed in single `'` or double `"` quotes. Strings containing a variable must only be enclosed in double `"` quotes to ensure the variable is expanded. For example:

    `MAILTO=postmaster@mail.example.net`

    `./cf-dns.sh -d example.com -t TXT -n _dmarc -c "v=DMARC1; p=none; pct=100; rua=mailto:$MAILTO; sp=none; aspf=r;" -l 1`

- A double `"` quote *contained* in a Comment [`-C COMMENT`] is replaced with a single `'` quote by the script to avoid the error `{"code":9207,"message":"Request body is invalid."}`. 

- As Cloudflare only allows a maximum Comment [`-C COMMENT`] length of 100 characters, the script truncates them to 97 characters and appends `...` .  

## Authentication

Your Cloudflare credentials are read from a file. Rename `auth.json.template` as `auth.json` and enter your Cloudflare credentials:

```
{
    "cloudflare": {
        "email": "your-cloudflare-email",
        "key": "your-cloudflare-api-key",
        "token": "your-cloudflare-api-token"
    }
}
```

`email` and `key` are required if you use a legacy [API key](https://developers.cloudflare.com/api/keys) to authenticate. `token` is required if you authenticate using the preferred [API token](https://developers.cloudflare.com/api/tokens). By default, the script uses your API token. If you want it to use your API key instead you must use the `-k` option.

## How the Script Works

A domain or site on your Cloudflare account is known as a zone and is assigned a unique 32-character ID by Cloudflare when it's created. A zone contains various DNS records each of which is also assigned its own unique 32-character ID by Cloudflare. A DNS record consists of data identifying its type, name and content amongst other information.

To add a new DNS record the domain's zone ID has to be passed to the Cloudflare API. To update or delete an existing DNS record both the domain's zone ID and the DNS record ID must be passed to the Cloudflare API. The zone ID can be found on the domain's *Overview* page on the Cloudflare dashboard or by using the Cloudflare API to list zones on your Cloudflare account. DNS record IDs can only be found by using the Cloudflare API to list a zone's DNS records. These API calls produce a lot of output and the (correct) IDs can be difficult to find. 

The script helps streamline this process by not needing to know the zone ID and DNS record ID beforehand. 

Consider the following DNS records for the `example.com` domain: 

| #       | Type       | Comment               | Name              | Content                              | Priority  | Proxy          | TTL        |   
|---------|------------| ----------------------|-------------------|--------------------------------------|-----------|----------------|------------| 
| 1       | A          | 'A' Record            | example.com       | 203.0.113.50                         | N/A       | DNS Only       | Auto       |
| ***2*** | ***AAAA*** | ***'AAAA' Record***   | ***example.com*** | ***2001:db8:c010:46d6::1***          | ***N/A*** | ***Proxied***  | ***Auto*** |
| 3       | CNAME      | 'CNAME' Record        | www               | example.com                          | N/A       | Proxied        | Auto       |
| 4       | MX         | 1st 'MX' Record       | example.com       | alt2.aspmx.l.google.com              | 10        | DNS only       | Auto       |
| 5       | MX         | 2nd 'MX' Record       | example.com       | aspmx.l.google.com                   | 10        | DNS only       | Auto       |
| ***6*** | ***MX***   | ***3rd 'MX' Record*** | ***example.com*** | ***mail.example.com***               | ***20***  | ***DNS only*** | ***1hr***  |
| 7       | TXT        | 'DKIM' Record         | dkim._domainkey   | v=DKIM1; p=MFswDQYJKoZIhvc...        | N/A       | DNS only       | Auto       |
| 8       | TXT        | 'DMARC' Record        | _dmarc            | v=DMARC1; p=none; pct=100; r...      | N/A       | DNS only       | Auto       | 
| 9       | TXT        | 'SPF' Record          | example.com       | v=spf1 mx ~all                       | N/A       | DNS only       | Auto       |

To demonstrate how the script works, let's assume that neither the **AAAA** record (#2) nor the **MX** record pointing to **mail.example.com** (#6) exist.

---

To attempt to add the **AAAA** record with the script I use:

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -x y -l 1 -C "'AAAA' Record"`

The script executes these steps:

1. It attempts to get the zone ID of the domain (`-d DOMAIN`).
2. If successful, it then tries to find a single DNS record for that zone that matches a combination of type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`).
3. If no matching DNS record is found, it further looks for *all* DNS records for the zone using only type (`-t TYPE`) and name (`-n NAME`).
4. If still no matches are found, a new DNS record is created.

----

To attempt to add the **MX** record with the script I use:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.com -p 20 -x N -l 3600 -C "3rd 'MX' Record"`

As with the previous example, the script executes steps 1 to 2. However, on executing step 3 it finds two existing records (#4 and #5) that match type (`-t TYPE`) and name (`-n NAME`) and so displays the following interactive prompt:

```
Found 2 existing DNS record(s) whose type is 'MX' named 'example.com'
[1] ID:s5stc17nr83o0szd9rsn9cx56tybwuo0, TYPE:MX, NAME:example.com, CONTENT:aspmx.l.google.com
[2] ID:a38q5zlhnhpycw05xld4gvlpb8ucelfd, TYPE:MX, NAME:example.com, CONTENT:alt2.aspmx.l.google.com
[A] Add New DNS Record
[Q] Quit

Type '1' or '2' to update an existing record, 'A' to add a new record or 'Q' to quit without changes and then press enter:
```
As I want to add a new DNS record, I type `A` and press enter and a new DNS record is created.

---

Having created this new **MX** record, I decide to change the *Priority* from **20** to **15** using:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.com -p 15`

On this occasion, when executing step 2, the script finds the single existing record that matches type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`) and simply changes its priority to `15`.

---

Later I realise I've made a mistake. This new **MX** record should point to **mail.example.net** and not **mail.example.com**. To change its *Content* I use:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.net`

On executing step 3 the script now finds three existing records (#4, #5 and #6) that match type (`-t TYPE`) and name (`-n NAME`) and so displays the following interactive prompt:

```
Found 3 existing DNS record(s) whose type is 'MX' named 'example.com'
[1] ID:s5stc17nr83o0szd9rsn9cx56tybwuo0, TYPE:MX, NAME:example.com, CONTENT:aspmx.l.google.com
[2] ID:a38q5zlhnhpycw05xld4gvlpb8ucelfd, TYPE:MX, NAME:example.com, CONTENT:alt2.aspmx.l.google.com
[3] ID:ge8m5b52vjm4uv22kbk7ba506obuknnn, TYPE:MX, NAME:example.com, CONTENT:mail.example.com
[A] Add New DNS Record
[Q] Quit

Type '1', '2' or '3' to update an existing record, 'A' to add a new record or 'Q' to quit without changes and then press enter:
```

Rather than add a new record, I want to update an existing record and so type `3` and press enter to update the appropriate record.

---

When deleting a record, the script only ever performs steps 1 and 2. If it can't find a record matching type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`), it exits.

To delete the **MX** record now pointing to **mail.example.net** use:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.net -Z`

## Examples

#### Add New DNS Records

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -x N -l 1 -C "'A' Record"`

| Type | Comment    | Name        | Content      | Priority | Proxy status | TTL  |
| ---- | ---------- | ----------- | ------------ | -------- | ------------ | ---- |
| A    | 'A' Record | example.com | 203.0.113.50 | N/A      | DNS Only     | Auto |

<br />

:point_right: As Cloudflare defaults **Proxy status** to _DNS Only_ (`false`) and **TTL** to _Auto_ (`1`), the following are functionally equivalent:

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -x N -C "'A' Record"`

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -C "'A' Record"`

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -C "'A' Record"`

---

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -x y -l 1 -C "'AAAA' Record"` 

| Type | Comment      | Name        | Content               | Priority | Proxy status   | TTL  |
|------|------------- |-------------|-----------------------|----------|----------------|------|
| AAAA |'AAAA' Record | example.com | 2001:db8:c010:46d6::1 | N/A      | Proxied        | Auto |

---

`./cf-dns.sh -d example.com -t CNAME -n www -c example.com -x Y -l 120 -C "'CNAME' Record"`

| Type  | Comment        | Name | Content     | Priority | Proxy status | TTL  |
| ----- | -------------- | ---- | ----------- | -------- | ------------ | ---- |
| CNAME | 'CNAME' Record | www  | example.com | N/A      | Proxied      | Auto |

<br />

:point\_right: Despite attempting to set the **TTL** to _2 min_ (`120`), the script forces a **TTL** of _Auto_ (`1`) as Cloudflare only allows records with a **Proxy status** of _DNS Only_ (`false`) to have a **TTL** other than _Auto_ (`1`). 

---

`./cf-dns.sh -d example.com -t MX -n example.com -c alt2.aspmx.l.google.com -p 10 -l 1 -C "1st 'MX' Record"`

| Type | Comment           | Name        | Content                 | Priority | Proxy status | TTL  |
| ---- | ----------------- | ----------- | ----------------------- | -------- | ------------ | ---- |
| MX   | 1st 'MX' Record   | example.com | alt2.aspmx.l.google.com | 10       | DNS Only     | Auto |

<br />

:point_right: As the script defaults **Priority** to _10_ and Cloudflare defaults **TTL** to _Auto_ (`1`), the following are functionally equivalent:

`./cf-dns.sh -d example.com -t MX -n example.com -c alt2.aspmx.l.google.com -p 10 -C "1st 'MX' Record"`

`./cf-dns.sh -d example.com -t MX -n example.com -c alt2.aspmx.l.google.com -l 1 -C "1st 'MX' Record"`

`./cf-dns.sh -d example.com -t MX -n example.com -c alt2.aspmx.l.google.com -C "1st 'MX' Record"`

---

`./cf-dns.sh -d example.com -t MX -n example.com -c aspmx.l.google.com -C "2nd 'MX' Record"`

| Type | Comment           | Name        | Content            | Priority | Proxy status | TTL  |
| ---- | ----------------- | ----------- | ------------------ | -------- | ------------ | ---- |
| MX   | 1st 'MX' Record   | example.com | aspmx.l.google.com | 10       | DNS Only     | Auto |

---

`./cf-dns.sh -d example.com -t TXT -n dkim._domainkey -c 'v=DKIM1; p=MFswDQYJKoZIhvcNAQEBBQADSgAwRwJAXemJxxGR7kgbyS2FK8FOtCxAgPHW9mA7SCcHK77dWM2wBTZyKRxd7eJARaaWHS1B4CxDdWh02Eqy7mygwUwZSwIDAQAB' -l 1 -C "'DKIM' Record"` 

| Type | Comment       | Name            | Content                       | Priority | Proxy status | TTL  |
| ---- | ------------- | --------------- | ----------------------------- | -------- | ------------ | ---- |
| TXT  | 'DKIM' Record | dkim._domainkey | v=DKIM1; p=MFswDQYJKoZIhvc... | N/A      | DNS only     | Auto |

---

`./cf-dns.sh -d example.com -t TXT -n _dmarc -c 'v=DMARC1; p=none; pct=100; rua=mailto:postmaster@mail.example.net; sp=none; aspf=r;' -l 1 -C "'DMARC' Record" -k` 

| Type | Comment        | Name   | Content                         | Priority | Proxy status | TTL  |
| ---- | -------------- | ------ | ------------------------------- | -------- | ------------ | ---- |
| TXT  | 'DMARC' Record | _dmarc | v=DMARC1; p=none; pct=100; r... | N/A      | DNS only     | Auto |

:point\_right: This example uses the legacy API key (`-k`) to authenticate.

---

`./cf-dns.sh -d example.com -t TXT -n example.com -c "v=spf1 mx ~all" -x Y -l 1 -C "'SPF' Record"`

| Type | Comment      | Name        | Content        | Priority | Proxy status | TTL  |
| ---- | ------------ | ----------- | -------------- | -------- | ------------ | ---- |
| TXT  | 'SPF' Record | example.com | v=spf1 mx ~all | N/A      | DNS Only     | Auto |

<br />

:point_right: Despite attempting to set the **Proxy status** to _Proxied_ (`true`), the script does not include this in the payload as MX and TXT records are not proxiable on Cloudflare which forces **Proxy status** to _DNS Only_ (`false`) for these record types.

---


#### Update Existing DNS Records

`./cf-dns.sh -d example.com -t A -n example.com -c 198.51.100.54`

| Type | Comment    | Name        | Content             | Priority | Proxy status | TTL  |
| ---- | ---------- | ----------- | ------------------- | -------- | ------------ | ---- |
| A    | 'A' Record | example.com | _**198.51.100.54**_ | N/A      | DNS Only     | Auto |

---

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -x n`

| Type | Comment       | Name        | Content               | Priority | Proxy status   | TTL  |
| ---- | ------------- | ----------- | --------------------- | -------- | -------------- | ---- |
| AAAA | 'AAAA' Record | example.com | 2001:db8:c010:46d6::1 | N/A      | _**DNS only**_ | Auto |

---

`./cf-dns.sh -d example.com -t CNAME -n www -c example.com -C "Cloudflare truncates comments longer than 100 characters, and doesn't support record tags on its free plan."` 

| Type  | Comment                                                                                                    | Name | Content     | Priority | Proxy status | TTL  |
| ----- | ---------------------------------------------------------------------------------------------------------- | ---- | ----------- | -------- | ------------ | ---- |
| CNAME | _**Cloudflare truncates comments longer than 100 characters, and doesn't support record tags on its ...**_ | www  | example.com | N/A      | Proxied      | Auto |

<br />

:point_right: As Cloudflare only allows comments upto a maximum of 100 characters, the script truncates comments longer than 97 characters and appends `...`.

---

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.com -p 15 -l 3600`

| Type | Comment           | Name        | Content          | Priority | Proxy status | TTL        |
| ---- | ----------------- | ----------- | ---------------- | -------- | ------------ | ---------- |
| MX   | First 'MX' Record | example.com | mail.example.com | _**15**_ | DNS Only     | _**1 hr**_ |

---

`./cf-dns.sh -d veward.com -t TXT -n dkim._domainkey -c 'v=DKIM1; p=MFswDQYJKoZIhvcNAQEBBQADSgAwRwJAYWXi4K8r0xVWXeY5b7nXrdO24E1Yd7bv /mNIGcR0FlHdf2Ng3gO1fzAq/x/ae2PIhG1TEj2+mh1BVK1u2oc7/wIDAQAB' -l 1`

| Type | Name            | Content                             | Priority | Proxy status | TTL  |
| ---- | --------------  | ----------------------------------- | -------- | ------------ | ---- |
| TXT  | dkim._domainkey | v=DKIM1; p=_**MFswDQYJKoZIhvc...**_ | N/A      | DNS only     | Auto |

---

`./cf-dns.sh -d example.com -t TXT -n _dmarc -c 'v=DMARC1; p=quarantine; pct=75; rua=mailto:postmaster@mail.example.net; sp=reject; aspf=r;' -l 1`

| Type | Name   | Content                                          | Priority | Proxy status | TTL  |
| ---- | ------ | ------------------------------------------------ | -------- | ------------ | ---- |
| TXT  | _dmarc | v=DMARC1; p=_**quarantine**_; pct=_**75**_; r... | N/A      | DNS only     | Auto |

---

#### Delete Existing DNS Records

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -Z -a`

| Type | Name        | Content      | Priority | Proxy status | TTL  |
| ---- | ----------- | ------------ | -------- | ------------ | ---- |
| A    | example.com | 203.0.113.50 | N/A      | Proxied      | Auto |

:point_right: This example uses the `-a` option which suppresses the prompt asking to confirm deletion.

A DNS record to be deleted is only matched using the combined values of type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`). If no match is found, a second attempt using only type (`-t TYPE`), and name (`-n NAME`) is not made as it is when adding or updating a DNS record.

---

<br />

## Limitations

- Requires an existing zone record for the domain being updated.

- Only **A**, **AAAA**, **CNAME**, **MX** and **TXT** type DNS records can be added, updated or deleted.

- Does not support record tags as these are not available on Cloudflare's Free plan.

- The script is unable to match a record using a combination of type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`) if the content contains a comma (`,`). While this appears to be an issue with the Cloudflare API, the script cannot currently delete DNS records whose content contains a comma (`,`) and may require user interaction to update such records.

## Get an Existing Domain's Current DNS Records

`get-dns.py` is a script that gets all of an existing domain's current DNS records. For each DNS record it displays a sub-Set of the data returned from the API call together with the arguments required to delete that record and create it using the `cf-dns.sh` script. It can optionally include all of the record's data as raw JSON. Output can be directed to a file or to the user's screen.

### Usage
`./get-dns.py -h/--help`

`./get-dns.py -d/--domain DOMAIN [-k/--key] [-p/--pretty] [-r/--raw] [-s/--screen]`

### Example

`./get-dns.py --domain=example.com --raw --screen`

### Sample Output

```
...

Record: 4/7 

{
    "comment": "2nd 'MX' Record",
    "content": "aspmx.l.google.com",
    "created_on": "2020-09-17T11:18:19.583054Z",
    "id": "7bdb2e46037df332e5abdd45f8f981f5",
    "meta": {},
    "modified_on": "2020-09-17T11:18:19.583054Z",
    "name": "example.com",
    "priority": 5,
    "proxiable": false,
    "proxied": false,
    "settings": {},
    "tags": [],
    "ttl": 3600,
    "type": "MX"
}

Domain: example.com
Type: MX
Name: example.com
Content: aspmx.l.google.com
Priority: 5
Proxiable: False
Proxied: False
TTL: 3600
Comment: 2nd 'MX' Record
Modified: 2020-09-17T11:18:19.583054Z
./cf-dns.sh -d example.com -t MX -n example.com -c aspmx.l.google.com -p 5 -l 3600 -C "2nd 'MX' Record" [-k] [-S] [-A]
./cf-dns.sh -d example.com -t MX -n example.com -c aspmx.l.google.com -Z [-a] [-k] [-S]

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

Record: 5/7

...

```