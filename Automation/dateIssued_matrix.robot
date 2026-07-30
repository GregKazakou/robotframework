*** Settings ***
Documentation    e-Invoice dateIssued format matrix — 8.4 / 8.6 / 11.1 / 1.1.
...
...              For EACH document template we run 8 variants of dateIssued:
...                1. today T00:00:00            (naive)
...                2. today T00:00:00Z           (UTC)
...                3. today T00:00:00+<GR>       (current Athens offset, DST-aware)
...                4. today T00:00:00+00:00
...                5. current datetime           (naive)
...                6. current datetime + 'Z'
...                7. current datetime + '+<GR>'
...                8. current datetime + '+00:00'
...
...              Series is stamped with a representative token per run
...              (e.g. FNB-RETAIL-NOW-ATH-20260701-120043) so each of the
...              32 runs is identifiable.
...
...              === Business rules verified (GR timezone) ===
...              The application works in Greece local time (Europe/Athens):
...                * payload time literally 00:00:00  -> the app stamps the
...                  document with the CURRENT submission time
...                * a UTC marker ('Z' / '+00:00')    -> converted to Athens
...                  (e.g. 14:30Z must display as 17:30 in summer)
...                * naive datetime (no offset)       -> already Athens local
...                * the portal always displays Athens wall-clock time
...
...              Per run we assert:
...                * HTTP 201 + status=SUBMITTED
...                * (optional) response dateIssued echoes the SAME offset
...                  flavour we sent — toggle ${CHECK_FORMAT_ECHO}
...                * response dateIssued == the EXPECTED Athens time per the
...                  rules above (±${SKEW_MINUTES} min)
...                * the portal HTML <td class="font-weight-bold"> datetime
...                  (dd/mm/yyyy HH:MM π.μ./μ.μ.) shows the CORRECT Greece
...                  time per the rules above (±${SKEW_MINUTES} min)
...
...              Requires InvoiceHelpers.py next to this file and
...              config/credentials.py on the Variables path.
...              On Windows also `pip install tzdata` (zoneinfo database).

Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          String
Library          DateTime
Library          ${CURDIR}/InvoiceHelpers.py
Variables        ${EXECDIR}/config/credentials.py

Suite Setup      Build Variant Matrix
Test Template    Run Variant Case

*** Variables ***
${DATA_DIR}           ${CURDIR}/Data
${RESULTS_DIR}        ${CURDIR}/Results
${BASE_URL}           ${UAT_API}
${ENDPOINT}           /invoice/json    # invoices (8.6 / 11.1 / 1.1)
${EP_RECEIPT}         /Receipt         # 8.4 POS receipts
${API_KEY}            ${EINVOICE_API_KEY}
${ISSUER_VAT}         ${ISSUER_TIN}
${DocumentTypeCode}   INVOICE

# Tolerance in minutes for "same time within a few minutes" (response + HTML).
${SKEW_MINUTES}       ${10}

# Set to ${True} to treat 'Z' and '+00:00' as equivalent formats (loose).
# Default ${False} => require exact wire-format match.
${LOOSE_FORMAT}       ${False}

# Check that the response echoes the same offset flavour that was sent.
# UAT finding (2026-07): the API NORMALIZES the format instead of echoing —
# /Receipt & 8.6 always return '...Z' (+ms), 11.1 returns '+00:00' — so the
# echo check stays OFF by default. Enable only to re-document that behaviour.
${CHECK_FORMAT_ECHO}  ${False}

# CounterParty VAT for templates with a 'CounterPartyVat' placeholder (1.1).
${COUNTERPARTY_VAT}   ${RECIPIENT_TIN}

@{ALL_VARIANTS}       # populated by Suite Setup

*** Test Cases ***
# One test case per (template x dateIssued variant) so a failure pinpoints
# the exact document type AND datetime case.
#
# Columns:            JSON template                        Series    Group  Flavour
# Groups:   MID = 00:00:00 (app must stamp submission time)   NOW = current time
# Flavours: NAIVE = no offset (=Athens)   Z / P00 = UTC (must convert to Athens)
#           ATH = current Greece offset (already Athens)

# ---- 8.4 POS Receipt --------------------------------------------------------
TC 01 - 8.4 POS - 00:00:00 naive stamps submission time
    [Tags]    matrix    8.4    MID    NAIVE
    8.4_POS_Receipt.json    POS84    MID    NAIVE

TC 02 - 8.4 POS - 00:00:00Z stamps submission time
    [Tags]    matrix    8.4    MID    Z
    8.4_POS_Receipt.json    POS84    MID    Z

TC 03 - 8.4 POS - 00:00:00+GR stamps submission time
    [Tags]    matrix    8.4    MID    ATH
    8.4_POS_Receipt.json    POS84    MID    ATH

TC 04 - 8.4 POS - 00:00:00+00:00 stamps submission time
    [Tags]    matrix    8.4    MID    P00
    8.4_POS_Receipt.json    POS84    MID    P00

TC 05 - 8.4 POS - now naive displays as Athens time
    [Tags]    matrix    8.4    NOW    NAIVE
    8.4_POS_Receipt.json    POS84    NOW    NAIVE

TC 06 - 8.4 POS - now Z converts UTC to Athens
    [Tags]    matrix    8.4    NOW    Z
    8.4_POS_Receipt.json    POS84    NOW    Z

TC 07 - 8.4 POS - now +GR keeps Athens time
    [Tags]    matrix    8.4    NOW    ATH
    8.4_POS_Receipt.json    POS84    NOW    ATH

TC 08 - 8.4 POS - now +00:00 converts UTC to Athens
    [Tags]    matrix    8.4    NOW    P00
    8.4_POS_Receipt.json    POS84    NOW    P00

# ---- 8.6 FNB Form -----------------------------------------------------------
TC 09 - 8.6 FNB - 00:00:00 naive stamps submission time
    [Tags]    matrix    8.6    MID    NAIVE
    8.6_Debit_FNB_Form.json    FNB86    MID    NAIVE

TC 10 - 8.6 FNB - 00:00:00Z stamps submission time
    [Tags]    matrix    8.6    MID    Z
    8.6_Debit_FNB_Form.json    FNB86    MID    Z

TC 11 - 8.6 FNB - 00:00:00+GR stamps submission time
    [Tags]    matrix    8.6    MID    ATH
    8.6_Debit_FNB_Form.json    FNB86    MID    ATH

TC 12 - 8.6 FNB - 00:00:00+00:00 stamps submission time
    [Tags]    matrix    8.6    MID    P00
    8.6_Debit_FNB_Form.json    FNB86    MID    P00

TC 13 - 8.6 FNB - now naive displays as Athens time
    [Tags]    matrix    8.6    NOW    NAIVE
    8.6_Debit_FNB_Form.json    FNB86    NOW    NAIVE

TC 14 - 8.6 FNB - now Z converts UTC to Athens
    [Tags]    matrix    8.6    NOW    Z
    8.6_Debit_FNB_Form.json    FNB86    NOW    Z

TC 15 - 8.6 FNB - now +GR keeps Athens time
    [Tags]    matrix    8.6    NOW    ATH
    8.6_Debit_FNB_Form.json    FNB86    NOW    ATH

TC 16 - 8.6 FNB - now +00:00 converts UTC to Athens
    [Tags]    matrix    8.6    NOW    P00
    8.6_Debit_FNB_Form.json    FNB86    NOW    P00

# ---- 11.1 FNB Retail --------------------------------------------------------
TC 17 - 11.1 Retail - 00:00:00 naive stamps submission time
    [Tags]    matrix    11.1    MID    NAIVE
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    MID    NAIVE

TC 18 - 11.1 Retail - 00:00:00Z stamps submission time
    [Tags]    matrix    11.1    MID    Z
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    MID    Z

TC 19 - 11.1 Retail - 00:00:00+GR stamps submission time
    [Tags]    matrix    11.1    MID    ATH
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    MID    ATH

TC 20 - 11.1 Retail - 00:00:00+00:00 stamps submission time
    [Tags]    matrix    11.1    MID    P00
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    MID    P00

TC 21 - 11.1 Retail - now naive displays as Athens time
    [Tags]    matrix    11.1    NOW    NAIVE
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    NOW    NAIVE

TC 22 - 11.1 Retail - now Z converts UTC to Athens
    [Tags]    matrix    11.1    NOW    Z
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    NOW    Z

TC 23 - 11.1 Retail - now +GR keeps Athens time
    [Tags]    matrix    11.1    NOW    ATH
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    NOW    ATH

TC 24 - 11.1 Retail - now +00:00 converts UTC to Athens
    [Tags]    matrix    11.1    NOW    P00
    11.1_FNB_Retail_Sales_Receipt.json    FNB111    NOW    P00

# ---- 1.1 B2B ----------------------------------------------------------------
TC 25 - 1.1 B2B - 00:00:00 naive stamps submission time
    [Tags]    matrix    1.1    MID    NAIVE
    1.1_B2B.json    B2B11    MID    NAIVE

TC 26 - 1.1 B2B - 00:00:00Z stamps submission time
    [Tags]    matrix    1.1    MID    Z
    1.1_B2B.json    B2B11    MID    Z

TC 27 - 1.1 B2B - 00:00:00+GR stamps submission time
    [Tags]    matrix    1.1    MID    ATH
    1.1_B2B.json    B2B11    MID    ATH

TC 28 - 1.1 B2B - 00:00:00+00:00 stamps submission time
    [Tags]    matrix    1.1    MID    P00
    1.1_B2B.json    B2B11    MID    P00

TC 29 - 1.1 B2B - now naive displays as Athens time
    [Tags]    matrix    1.1    NOW    NAIVE
    1.1_B2B.json    B2B11    NOW    NAIVE

TC 30 - 1.1 B2B - now Z converts UTC to Athens
    [Tags]    matrix    1.1    NOW    Z
    1.1_B2B.json    B2B11    NOW    Z

TC 31 - 1.1 B2B - now +GR keeps Athens time
    [Tags]    matrix    1.1    NOW    ATH
    1.1_B2B.json    B2B11    NOW    ATH

TC 32 - 1.1 B2B - now +00:00 converts UTC to Athens
    [Tags]    matrix    1.1    NOW    P00
    1.1_B2B.json    B2B11    NOW    P00

*** Keywords ***

# =============================================================================
# SUITE SETUP
# =============================================================================

Build Variant Matrix
    [Documentation]    Builds the 8 datetime variants once and stores them as a
    ...                suite variable for all templates to reuse.
    ${variants}=    Build Datetime Variants
    Set Suite Variable    @{ALL_VARIANTS}    @{variants}
    Length Should Be    ${ALL_VARIANTS}    8
    Log    Built ${ALL_VARIANTS.__len__()} datetime variants.    INFO


# =============================================================================
# TEST TEMPLATE
# =============================================================================

Run Variant Case
    [Documentation]    Test-template entry point: resolves ONE datetime variant
    ...                by (group, flavour) and runs the full check for it.
    ...                One Robot test case == one exact dateIssued scenario.
    [Arguments]    ${json_filename}    ${series_prefix}    ${group}    ${flavour}

    ${variant}=    Find Variant    ${ALL_VARIANTS}    ${group}    ${flavour}
    ${idx}=        Get Variant Field    ${variant}    index
    ${sent}=       Get Variant Field    ${variant}    date_issued
    ${name}=       Set Variable    ${series_prefix}-V${idx}-${group}-${flavour}

    Log    Case ${name}: sending dateIssued=${sent}    INFO
    Run Single Variant    ${json_filename}    ${series_prefix}    ${variant}    ${name}


# =============================================================================
# SINGLE VARIANT
# =============================================================================

Run Single Variant
    [Documentation]    Loads template, injects the variant dateIssued + a
    ...                representative Series, POSTs, verifies response format &
    ...                skew, then verifies the portal HTML datetime.
    [Arguments]    ${json_filename}    ${series_prefix}    ${variant}    ${run_name}

    ${sent_dt}=    Get Variant Field    ${variant}    date_issued

    # --- Build payload -----------------------------------------------------
    ${payload}=    Load Invoice Json    ${json_filename}
    ${series}=     Build Series    ${series_prefix}    ${variant}
    ${payload}=    Apply Runtime Overrides    ${payload}    ${series}    ${sent_dt}

    # --- POST --------------------------------------------------------------
    ${endpoint}=        Resolve Endpoint For Template    ${json_filename}
    ${submitted_at}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S
    ${body}    ${mark}    ${url}=    Post Invoice And Verify    ${payload}    ${run_name}    ${endpoint}

    # --- Response dateIssued checks ---------------------------------------
    ${resp_dt}=    Get Response Date Issued    ${body}
    IF    ${CHECK_FORMAT_ECHO}
        ${strict}=     Evaluate    not ${LOOSE_FORMAT}
        Verify Sent Vs Response Format    ${sent_dt}    ${resp_dt}    strict=${strict}
    END
    ${resp_check}=    Verify Response Datetime Gr    ${sent_dt}    ${resp_dt}
    ...               max_minutes=${SKEW_MINUTES}    submitted_at=${submitted_at}
    Log    Response GR check OK — ${resp_check}    INFO

    # --- Portal HTML check: correct Greece time per business rules ---------
    Verify Portal Html Datetime GR    ${url}    ${sent_dt}    ${submitted_at}

    Log    ${run_name}: sent=${sent_dt} resp=${resp_dt} mark=${mark}    INFO


Apply Runtime Overrides
    [Documentation]    Sets Series/series, Number/number, dateIssued (both key
    ...                casings if present), Issuer.Vat, InternalDocumentId, and
    ...                any providerSignatureIdentifier placeholder.
    [Arguments]    ${payload}    ${series}    ${date_issued}

    ${new}=      Evaluate    copy.deepcopy($payload)    copy
    ${number}=   Generate Unique Number
    ${guid}=     Evaluate    str(uuid.uuid4())    uuid

    Set Key If Present    ${new}    Series          ${series}
    Set Key If Present    ${new}    series          ${series}
    Set Key If Present    ${new}    Number          ${number}
    Set Key If Present    ${new}    number          ${number}
    Set Key If Present    ${new}    dateIssued      ${date_issued}
    Set Key If Present    ${new}    DateIssued      ${date_issued}
    Set Key If Present    ${new}    providerSignatureIdentifier    ${guid}
    Set Key If Present    ${new}    ProviderSignatureIdentifier    ${guid}
    Set Key If Present    ${new}    internalDocumentId    ${guid}
    Set Key If Present    ${new}    InternalDocumentId    ${guid}

    # Issuer VAT from credentials
    ${has_issuer}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${new}    Issuer
    IF    ${has_issuer}
        ${issuer}=    Get From Dictionary    ${new}    Issuer
        Set To Dictionary    ${issuer}    Vat    ${ISSUER_VAT}
        Set To Dictionary    ${new}       Issuer    ${issuer}
    END

    # CounterParty VAT (1.1 template ships a 'CounterPartyVat' placeholder)
    ${has_cp}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${new}    CounterParty
    IF    ${has_cp}
        ${cp}=    Get From Dictionary    ${new}    CounterParty
        Set To Dictionary    ${cp}     Vat    ${COUNTERPARTY_VAT}
        Set To Dictionary    ${new}    CounterParty    ${cp}
    END

    # DistributionDetails.InternalDocumentId if present
    ${has_dist}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${new}    DistributionDetails
    IF    ${has_dist}
        ${dist}=    Get From Dictionary    ${new}    DistributionDetails
        Set To Dictionary    ${dist}    InternalDocumentId    ${guid}
        Set To Dictionary    ${new}     DistributionDetails    ${dist}
    END

    RETURN    ${new}


Set Key If Present
    [Documentation]    Sets ${key}=${value} on ${dict} only if the key already
    ...                exists (respects each template's own casing).
    [Arguments]    ${dict}    ${key}    ${value}
    ${present}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${dict}    ${key}
    IF    ${present}
        Set To Dictionary    ${dict}    ${key}    ${value}
    END


# =============================================================================
# POST + VERIFY
# =============================================================================

Resolve Endpoint For Template
    [Documentation]    8.4 POS receipts go to /Receipt; everything else
    ...                (8.6 / 11.1 / 1.1) goes to /invoice/json.
    [Arguments]    ${json_filename}
    ${is_receipt}=    Evaluate    $json_filename.startswith('8.4')
    IF    ${is_receipt}
        RETURN    ${EP_RECEIPT}
    END
    RETURN    ${ENDPOINT}


Post Invoice And Verify
    [Documentation]    POSTs ${payload} to ${endpoint}, asserts 201 + SUBMITTED,
    ...                saves result, returns (body, mark, url).
    [Arguments]    ${payload}    ${label}=invoice    ${endpoint}=${ENDPOINT}

    ${headers}=    Create Dictionary
    ...            Content-Type=application/json
    ...            apikey=${API_KEY}

    Create Session    einvoice    ${BASE_URL}    headers=${headers}    verify=${True}

    ${response}=    POST On Session    einvoice    ${endpoint}    json=${payload}
    ...             expected_status=any

    Should Be Equal As Integers    ${response.status_code}    201
    ...    msg=Expected HTTP 201, got ${response.status_code}: ${response.text}

    ${body}=     Set Variable    ${response.json()}
    Dictionary Should Contain Item    ${body}    status    SUBMITTED

    ${mark}=     Get From Dictionary    ${body}    mark
    ${url}=      Get From Dictionary    ${body}    url
    ${message}=  Get From Dictionary    ${body}    message

    Save Response Result
    ...    status_code=${response.status_code}    mark=${mark}
    ...    url=${url}    message=${message}    test_name=${label}

    Log    ${label}: HTTP ${response.status_code} mark=${mark} url=${url}    INFO
    RETURN    ${body}    ${mark}    ${url}


Get Response Date Issued
    [Documentation]    Reads dateIssued from the response body, tolerating both
    ...                camelCase and PascalCase keys.
    [Arguments]    ${body}
    ${has_camel}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${body}    dateIssued
    IF    ${has_camel}
        ${val}=    Get From Dictionary    ${body}    dateIssued
        RETURN    ${val}
    END
    ${has_pascal}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${body}    DateIssued
    IF    ${has_pascal}
        ${val}=    Get From Dictionary    ${body}    DateIssued
        RETURN    ${val}
    END
    Fail    Response body has no dateIssued / DateIssued key: ${body}


# =============================================================================
# PORTAL HTML VERIFY
# =============================================================================

Verify Portal Html Datetime GR
    [Documentation]    GETs the portal ${url}, extracts the bold-cell
    ...                dd/mm/yyyy HH:MM π.μ./μ.μ. datetime and asserts it shows
    ...                the CORRECT Greece local time per the app's rules:
    ...                midnight->submission time, UTC->Athens, naive=Athens.
    [Arguments]    ${url}    ${sent_dt}    ${submitted_at}

    ${headers}=    Create Dictionary    Accept=text/html
    ${resp}=       GET    ${url}    headers=${headers}    expected_status=any
    ...            verify=${True}

    Should Be Equal As Integers    ${resp.status_code}    200
    ...    msg=Portal GET failed: HTTP ${resp.status_code} for ${url}

    ${result}=    Verify Html Datetime Gr    ${resp.text}    ${sent_dt}
    ...           max_minutes=${SKEW_MINUTES}    submitted_at=${submitted_at}
    Log    Portal GR datetime OK — ${result}    INFO


Verify Portal Html Datetime
    [Documentation]    LEGACY wall-clock check (timezone-agnostic). Kept for
    ...                reference; the GR-aware keyword above is what the suite
    ...                now uses.
    [Arguments]    ${url}    ${sent_dt}

    ${headers}=    Create Dictionary    Accept=text/html
    ${resp}=       GET    ${url}    headers=${headers}    expected_status=any
    ...            verify=${True}

    Should Be Equal As Integers    ${resp.status_code}    200
    ...    msg=Portal GET failed: HTTP ${resp.status_code} for ${url}

    ${result}=    Verify Html Datetime    ${resp.text}    ${sent_dt}
    ...           max_minutes=${SKEW_MINUTES}
    Log    Portal datetime OK: ${result}    INFO


# =============================================================================
# JSON LOADING
# =============================================================================

Load Invoice Json
    [Documentation]    Reads a JSON file from ${DATA_DIR} and returns a dict.
    [Arguments]    ${filename}
    ${path}=    Set Variable    ${DATA_DIR}/${filename}
    ${raw}=     Get File        ${path}    encoding=UTF-8
    ${data}=    Evaluate        json.loads($raw)    json
    RETURN    ${data}


# =============================================================================
# GENERATORS
# =============================================================================

Generate Unique Number
    ${stamp}=    Evaluate
    ...    __import__('datetime').datetime.now().strftime('%y%m%d%H%M%S') + f"{__import__('datetime').datetime.now().microsecond // 1000:03d}"
    RETURN    ${stamp}


# =============================================================================
# RESULT PERSISTENCE
# =============================================================================

Save Response Result
    [Documentation]    Appends a row to Results/results.csv and writes a
    ...                per-run JSON snapshot.
    [Arguments]    ${status_code}    ${mark}    ${url}    ${message}    ${test_name}=invoice

    Create Directory    ${RESULTS_DIR}
    ${csv_path}=    Set Variable    ${RESULTS_DIR}/results.csv
    ${exists}=      Run Keyword And Return Status    File Should Exist    ${csv_path}

    ${ts}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S

    IF    not ${exists}
        Append To File    ${csv_path}    timestamp,test,status_code,mark,url,message\n
    END

    ${row}=    Set Variable    ${ts},${test_name},${status_code},${mark},${url},${message}\n
    Append To File    ${csv_path}    ${row}

    ${snapshot}=       Create Dictionary
    ...                status_code=${status_code}    mark=${mark}
    ...                url=${url}    message=${message}    test=${test_name}
    ${snapshot_json}=  Evaluate    json.dumps($snapshot, indent=2, ensure_ascii=False)    json
    ${safe_ts}=        Replace String    ${ts}    :    -
    Create File
    ...    ${RESULTS_DIR}/${test_name}_${safe_ts}.json
    ...    ${snapshot_json}

    Log    Saved result row to ${csv_path}    INFO
