*** Settings ***
Documentation    e-Invoice dateIssued format matrix — 8.4 / 8.6 / 11.1.
...
...              For EACH document template we run 8 variants of dateIssued:
...                1. today T00:00:00            (naive)
...                2. today T00:00:00Z           (UTC)
...                3. today T00:00:00+03:00
...                4. today T00:00:00+00:00
...                5. current datetime           (naive)
...                6. current datetime + 'Z'
...                7. current datetime + '+03:00'
...                8. current datetime + '+00:00'
...
...              Series is stamped with a representative token per run
...              (e.g. FNB-RETAIL-NOW-P03-20260701-120043) so each of the
...              24 runs is identifiable.
...
...              Per run we assert:
...                * HTTP 201 + status=SUBMITTED
...                * response dateIssued is the SAME offset flavour we sent
...                * response dateIssued wall-clock is within a few minutes
...                * the portal HTML <td class="font-weight-bold"> datetime
...                  (dd/mm/yyyy HH:MM π.μ./μ.μ.) is within a few minutes
...
...              Requires InvoiceHelpers.py next to this file and
...              config/credentials.py on the Variables path.

Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          String
Library          DateTime
Library          ${CURDIR}/InvoiceHelpers.py
Variables        ${EXECDIR}/config/credentials.py

Suite Setup      Build Variant Matrix

*** Variables ***
${DATA_DIR}           ${CURDIR}/Data
${RESULTS_DIR}        ${CURDIR}/Results
${BASE_URL}           ${UAT_API}
${ENDPOINT}           /invoice/json
${API_KEY}            ${EINVOICE_API_KEY}
${ISSUER_VAT}         ${ISSUER_TIN}
${DocumentTypeCode}   INVOICE

# Tolerance in minutes for "same time within a few minutes" (response + HTML).
${SKEW_MINUTES}       ${10}

# Set to ${True} to treat 'Z' and '+00:00' as equivalent formats (loose).
# Default ${False} => require exact wire-format match.
${LOOSE_FORMAT}       ${False}

@{ALL_VARIANTS}       # populated by Suite Setup

*** Test Cases ***

8.4 POS Receipt — dateIssued matrix
    [Tags]    matrix    8.4
    Run Datetime Matrix For Template    8.4_POS_Receipt.json    POS84

8.6 FNB Form — dateIssued matrix
    [Tags]    matrix    8.6
    Run Datetime Matrix For Template    8.6_Debit_FNB_Form.json    FNB86

11.1 FNB Retail — dateIssued matrix
    [Tags]    matrix    11.1
    Run Datetime Matrix For Template    11.1_FNB_Retail_Sales_Receipt.json    FNB111

1.1 B2B — dateIssued matrix
    [Tags]    matrix    1.1
    Run Datetime Matrix For Template    1.1_B2B.json    B2B11

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
# MATRIX DRIVER
# =============================================================================

Run Datetime Matrix For Template
    [Documentation]    Runs all 8 datetime variants against one JSON template.
    ...                Collects per-variant pass/fail and fails at the end if
    ...                any variant failed, so one bad format does not hide the
    ...                others.
    [Arguments]    ${json_filename}    ${series_prefix}

    @{failures}=    Create List

    FOR    ${variant}    IN    @{ALL_VARIANTS}
        ${idx}=       Get Variant Field    ${variant}    index
        ${label}=     Get Variant Field    ${variant}    offset_label
        ${group}=     Get Variant Field    ${variant}    group
        ${name}=      Set Variable    ${series_prefix}-V${idx}-${group}-${label}

        ${status}    ${err}=    Run Keyword And Ignore Error
        ...    Run Single Variant    ${json_filename}    ${series_prefix}    ${variant}    ${name}

        IF    '${status}' != 'PASS'
            Append To List    ${failures}    ${name}: ${err}
            Log    VARIANT FAILED — ${name}: ${err}    WARN
        ELSE
            Log    VARIANT OK — ${name}    INFO
        END
    END

    ${nfail}=    Get Length    ${failures}
    IF    ${nfail} > 0
        ${detail}=    Catenate    SEPARATOR=\n    @{failures}
        Fail    ${nfail}/8 variants failed for ${json_filename}:\n${detail}
    END


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
    ${body}    ${mark}    ${url}=    Post Invoice And Verify    ${payload}    ${run_name}

    # --- Response dateIssued checks ---------------------------------------
    ${resp_dt}=    Get Response Date Issued    ${body}
    ${strict}=     Evaluate    not ${LOOSE_FORMAT}
    Verify Sent Vs Response Format    ${sent_dt}    ${resp_dt}    strict=${strict}
    Verify Response Datetime Skew     ${sent_dt}    ${resp_dt}    max_minutes=${SKEW_MINUTES}

    # --- Portal HTML check -------------------------------------------------
    Verify Portal Html Datetime    ${url}    ${sent_dt}

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

Post Invoice And Verify
    [Documentation]    POSTs ${payload}, asserts 201 + SUBMITTED, saves result,
    ...                returns (body, mark, url).
    [Arguments]    ${payload}    ${label}=invoice

    ${headers}=    Create Dictionary
    ...            Content-Type=application/json
    ...            apikey=${API_KEY}

    Create Session    einvoice    ${BASE_URL}    headers=${headers}    verify=${True}

    ${response}=    POST On Session    einvoice    ${ENDPOINT}    json=${payload}
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

Verify Portal Html Datetime
    [Documentation]    GETs the portal ${url}, extracts the bold-cell
    ...                dd/mm/yyyy HH:MM π.μ./μ.μ. datetime and asserts it is
    ...                within ${SKEW_MINUTES} of the sent wall-clock time.
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
