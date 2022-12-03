# cloudflare-dns

## Purpose
Add, update or delete your domain's DNS records from the command line using the [Cloudflare API](https://api.cloudflare.com/#dns-records-for-a-zone-properties). 

## Background
I initially wrote this script as a quick way of repeatedly adding or updating DNS records for several domains from the command line when I was building and testing my mail server. ***If you're thinking of using it, it's important you read the [Limitations](#limitations) section first*** and check your domain's DNS records on Cloudflare afterwards. 

The script is based upon examples of using the Cloudflare API at [Using the Cloudflare API to Manage DNS Records](https://www.tech-otaku.com/web-development/using-cloudflare-api-manage-dns-records/).

## Usage
#### Help
`./cf-dns.sh -h`

#### Add or Update
`./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED [-k] [-s] [-o] [-A]`

#### Delete
`./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -Z [-a] [-k] [-s] [-o]`

## Options

Use `./cf-dns.sh -h` to see an explanation of the options and their usage.

In addition, please note the following:

- When adding a new DNS record or updating an existing one, all but the `-k` and `-o` options are required.<sup>**1**</sup> This is true even when updating an existing DNS record where not all the data is changing. 

    For example, to change only the content (`-c CONTENT`) for this record to `198.51.100.54` all data needs to be given:

    | Type | Name            | Content      | Priority | TTL  | Proxy status  |
    |:-----|:----------------|:-------------|:---------|:-----|:--------------|
    | A    | example.com     | 203.0.113.50 | N/A      | Auto | Proxied       |

    <br />

    `./cf-dns.sh -d example.com -t A -n example.com -c 198.51.100.54 -l 1 -x y`
    
    <br />

    | Type | Name            | Content      | Priority | TTL  | Proxy status  |
    |:-----|:----------------|:-------------|:---------|:-----|:--------------|
    | A    | example.com     | ***198.51.100.54*** | N/A      | Auto | Proxied       |

    <br />

    <sup>**1**</sup> When using the `-Z` option to delete a record, the only mandatory options are domain (`-d DOMAIN`), name (`-n NAME`), type (`-t TYPE`) and content (`-c CONTENT`). Optionally, use `-a` to suppress the prompt asking to confirm deletion.

- Priority (`-p PRIORITY`) is only required for `MX` type DNS records and is ignored for all other DNS record types.

    <br />  

- Proxied status (`-x PROXIED`) is not required for `MX` or `TXT` type DNS records and is ignored if specified. These DNS record types can not be proxied through Cloudflare.

    <br />  

- When specifying a TTL (`-l TTL`) other than `1` (Auto), the DNS record's proxy status will be automatically set to `DNS only` regardless of the value of `-x`. This is due to Cloudflare only allowing TTL values other than `1` for DNS records that are *not* proxied.

    <br />  

- The script checks if the domain name (`-d DOMAIN`) and DNS record name (`-n NAME`) are the same. If not, the domain name is appended to the DNS record name as per the table below (think `dig TXT example.com` and `dig TXT dkim._domainkey.example.com`). The `-o` option overrides this behaviour, but I can't recall why I initially included it. If used, the option is ignored and will be removed at a later date. 

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

| # | Type  | Name            | Content                              | Priority | TTL  |Proxy    | 
|---|-------|-----------------|--------------------------------------|----------|------|---------|
| 1 | A     | example.com     | 203.0.113.50                         | N/A      |Auto  | Proxied  | 
| ***2*** | ***AAAA***  | ***example.com***     | ***2001:db8:c010:46d6::1***                | ***N/A***      |***Auto*** | ***Proxied***  |
| 3 | CNAME | www             | example.com                          | N/A      |Auto  | Proxied  |
| 4 | MX    | example.com     | aspmx.l.google.com                   | 5        | 3600 | DNS only |
| 5 | MX    | example.com     | alt2.aspmx.l.google.com              | 5        | 3600 | DNS only |
| ***6*** | ***MX***    | ***example.com***     | ***mail.example.com***                     | ***5***       | ***Auto*** | ***DNS only*** |
| 7 | TXT   | dkim._domainkey | v=DKIM1; p=MFswDQYJKoZIhvXjTSNCGv... | N/A      | Auto | DNS only |
| 8 | TXT   | _dmarc          | v=DMARC1; p=quarantine; pct=75; r... | N/A      | Auto | DNS only |
| 9 | TXT   | example.com     | v=spf1 mx ~all                       | N/A      | Auto | DNS only |

To demonstrate how the script works, let's assume that neither the **AAAA** record (#2) nor the **MX** record pointing to **mail.example.com** (#6) exist.

---

To attempt to add the **AAAA** record with the script I use:

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -l 1 -x y`

The script executes these steps:

1. It attempts to get the zone ID of the domain (`-d DOMAIN`).
2. If successful, it then tries to find a single DNS record for that zone that matches a combination of type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`).
3. If no matching DNS record is found, it further looks for *all* DNS records for the zone using only type (`-t TYPE`) and name (`-n NAME`).
4. If still no matches are found, a new DNS record is created.

----

To attempt to add the **MX** record with the script I use:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.com -p 5 -l 1`

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

Having created this new **MX** record, I decide to change the *Priority* from **5** to **10** using:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.com -p 10 -l 1`

On this occasion, when executing step 2, the script finds the single existing record that matches type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`) and simply changes its priority to `10`.

---

Later I realise I've made a mistake. This new **MX** record should point to **mail.example.net** and not **mail.example.com**. To change its *Content* I use:

`./cf-dns.sh -d example.com -t MX -n example.com -c mail.example.net -p 10 -l 1`

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

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y`

<br />

| Type | Name            | Content      | Priority | TTL  | Proxy status  |
|:-----|:----------------|:-------------|:---------|:-----|:--------------|
| A    | example.com     | 203.0.113.50 | N/A      | Auto | Proxied       |

---

<br />

`./cf-dns.sh -d example.com -t CNAME -n www -c example.com -l 1 -x y`

<br />

| Type  | Name | Content         | Priority | TTL  | Proxy status  |
|:------|:-----|:----------------|:---------|:-----|:--------------|
| CNAME | www  | example.com     | N/A      | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -l 1 -x y` 

<br />

| Type | Name            | Content               | Priority | TTL   | Proxy status   |
|:-----|:----------------|:----------------------|:---------|:------|:---------------|
| AAAA | example.com     | 2001:db8:c010:46d6::1 | N/A      | Auto  | Proxied        |

---

<br />

`./cf-dns.sh -d example.com -t MX -n example.com -c aspmx.l.google.com -p 5 -l 1 -k`

<br />

NOTE: This example uses the legacy API key (`-k`) to authenticate.

<br />

| Type | Name            | Content            | Priority | TTL  | Proxy status  |
|:-----|:----------------|:-------------------|:---------|:-----|:--------------|
| MX   | example.com     | aspmx.l.google.com | 5        | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d example.com -t TXT -n dkim._domainkey -c 'v=DKIM1; p=MFswDQYJKoZIhvcNAQEBBQADSgAwRwJAXemJxxGR7kgbyS2FK8FOtCxAgPHW9mA7SCcHK77dWM2wBTZyKRxd7eJARaaWHS1B4CxDdWh02Eqy7mygwUwZSwIDAQAB' -l 1`

<br />

| Type | Name            | Content                       | Priority | TTL  | Proxy status  |
|:-----|:----------------|:------------------------------|:---------|:-----|:--------------|
| TXT  | dkim._domainkey | v=DKIM1; p=MFswDQYJKoZIhvc... | N/A      | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d example.com -t TXT -n _dmarc -c 'v=DMARC1; p=none; pct=100; rua=mailto:postmaster@mail.example.net; sp=none; aspf=r;' -l 1`

<br />

| Type | Name   | Content                         | Priority | TTL  | Proxy status  |
|:-----|:-------|:--------------------------------|:---------|:-----|:--------------|
| TXT  | _dmarc | v=DMARC1; p=none; pct=100; r... | N/A      | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d example.com -t TXT -n example.com -c 'v=spf1 mx ~all' -l 1`

<br />

| Type | Name            | Content        | Priority | TTL  | Proxy status  |
|------|-----------------|----------------|----------|------|---------------|
| TXT  | example.com     | v=spf1 mx ~all | N/A      | Auto | DNS only      |

---

<br />

#### Update Existing DNS Records

`./cf-dns.sh -d example.com -t A -n example.com -c 198.51.100.54 -l 1 -x y`

<br />

| Type | Name            | Content        | Priority | TTL  | Proxy status  |
|:-----|:----------------|:---------------|:---------|:-----|:--------------|
| A    | example.com     | ***198.51.100.54*** | N/A      | Auto | Proxied       |

---

<br />

`./cf-dns.sh -d example.com -t CNAME -n www -c example.com -l 300 -x n`

<br />

| Type  | Name | Content         | Priority | TTL   | Proxy status  |
|:------|:-----|:----------------|:---------|:------|:--------------|
| CNAME | www  | example.com     | N/A      | ***5 min*** | ***DNS only***      |

---

<br />

`./cf-dns.sh -d example.com -t AAAA -n example.com -c 2001:db8:c010:46d6::1 -l 1 -x n`

<br />

| Type | Name            | Content               | Priority | TTL   | Proxy status   |
|:-----|:----------------|:----------------------|:---------|:------|:---------------|
| AAAA | example.com     | 2001:db8:c010:46d6::1 | N/A      | Auto  | ***DNS only***       |

---

<br />

`./cf-dns.sh -d example.com -t MX -n example.com -c alt1.aspmx.l.google.com -p 10 -l 1`

<br />

| Type | Name            | Content                 | Priority | TTL  | Proxy status  |
|:-----|:----------------|:------------------------|:---------|:-----|:--------------|
| MX   | example.com     | ***alt1.aspmx.l.google.com*** | ***10***        | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d veward.com -t TXT -n dkim._domainkey -c 'v=DKIM1; p=MFswDQYJKoZIhvcNAQEBBQADSgAwRwJAYWXi4K8r0xVWXeY5b7nXrdO24E1Yd7bv /mNIGcR0FlHdf2Ng3gO1fzAq/x/ae2PIhG1TEj2+mh1BVK1u2oc7/wIDAQAB' -l 1`

<br />

| Type | Name            | Content                       | Priority | TTL  | Proxy status  |
|:-----|:----------------|:------------------------------|:---------|:-----|:--------------|
| TXT  | dkim._domainkey | v=DKIM1; p=***MFswDQYJKoZIhvc...*** | N/A      | Auto | DNS only      |

---

<br />

`./cf-dns.sh -d example.com -t TXT -n _dmarc -c 'v=DMARC1; p=quarantine; pct=75; rua=mailto:postmaster@mail.example.net; sp=reject; aspf=r;' -l 1`

<br />

| Type | Name   | Content                   | Priority | TTL  | Proxy status  |
|:-----|:-------|:--------------------------|:---------|:-----|:--------------|
| TXT  | _dmarc | v=DMARC1; p=***quarantine***; pct=***75***; r... | N/A      | Auto | DNS only      |

---

<br />

#### Delete Existing DNS Records

`./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -Z -a`

<br />

NOTE: This example uses the `-a` option which suppresses the prompt asking to confirm deletion.

<br />

| Type | Name            | Content      | Priority | TTL  | Proxy status  |
|:-----|:----------------|:-------------|:---------|:-----|:--------------|
| A    | example.com     | 203.0.113.50 | N/A      | Auto | Proxied       |

<br />

A DNS record to be deleted is only matched using the combined values of type (`-t TYPE`), name (`-n NAME`) and content (`-c CONTENT`). If no match is found, a second attempt using only type (`-t TYPE`), and name (`-n NAME`) is not made as it is when adding or updating a DNS record.

---

<br />

## Limitations

- Requires an existing zone record for the domain being updated.

- Only **A**, **AAAA**, **CNAME**, **MX** and **TXT** type DNS records can be added, updated or deleted.