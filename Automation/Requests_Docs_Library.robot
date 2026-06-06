*** Settings ***
Documentation    e-Invoice POST tests — 9.3 × 50 DN + 1.1 suite.
...
...              Workflow for "9.3_Sales_20lines & 50 DN":
...                1. Load and transform the 1000-item details[] directly
...                   from Data/1.1_B2B_DN.json (no extra file needed).
...                2. Split into 50 chunks of 20 items each.
...                3. For each chunk POST a 9.3 payload derived from
...                   9.3_Sales_20lines.json, collect the returned mark.
...                4. Load 1.1_B2B_DN.json, inject all 50 marks into
...                   deliveryNoteMarks[], override standard fields, POST.
...
...              Requires InvoiceHelpers.py on PYTHONPATH (place it next to this file).

Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          String
Library          DateTime
Library          ${CURDIR}/InvoiceHelpers.py
Variables         ${EXECDIR}/config/credentials.py

*** Variables ***
${DATA_DIR}           ${CURDIR}/Data
${RESULTS_DIR}        ${CURDIR}/Results
${BASE_URL}           ${UAT_API}
${ENDPOINT}           /invoice/json
${API_KEY}            ${EINVOICE_API_KEY}
${ISSUER_VAT}         ${ISSUER_TIN}
${COUNTER_PARTY_VAT}  ${RECIPIENT_TIN}
${TRANSPORTER_VAT}    ${TRANSPORTER_TIN}
${DocumentTypeCode}   INVOICE
${DN_CHUNK_SIZE}      ${20}
${DN_TOTAL}           ${50}
${DN_SOURCE_JSON}     all_1000_items.json
${INV_SOURCE_JSON}    all_1000_items_1.1.json

*** Test Cases ***

1.1_B2B
    [Tags]    smoke
    Submit Invoice And Verify    1.1_B2B.json

1.1_B2B_DN
    [Tags]    smoke
    Submit Invoice And Verify    1.1_B2B_DN.json
    ...    Override Distribution Dates    Override Payment Date


*** Keywords ***

# =============================================================================
# HIGH-LEVEL KEYWORDS
# =============================================================================

Submit Invoice And Verify
    [Documentation]    Generic single-payload POST. Loads JSON template,
    ...                applies base overrides + any extra keyword names,
    ...                POSTs, verifies 201/SUBMITTED, saves results.
    [Arguments]    ${json_filename}    @{extra_overrides}

    ${payload}=    Load Invoice Json              ${json_filename}
    ${payload}=    Override Placeholder Fields    ${payload}

    FOR    ${kw}    IN    @{extra_overrides}
        ${payload}=    Run Keyword    ${kw}    ${payload}
    END

    ${mark}=    Post Invoice And Verify    ${payload}    ${json_filename}
    RETURN    ${mark}

# -----------------------------------------------------------------------------


# =============================================================================
# POST + VERIFY
# =============================================================================

Post Invoice And Verify
    [Documentation]
    ...    POSTs ${payload} to ${ENDPOINT}, asserts HTTP 201 + status=SUBMITTED,
    ...    saves results, returns the mark.
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
    ...    status_code=${response.status_code}
    ...    mark=${mark}
    ...    url=${url}
    ...    message=${message}
    ...    test_name=${label}

    Log    ${label}: HTTP ${response.status_code} mark=${mark} url=${url}    INFO
    RETURN    ${mark}

# =============================================================================
# JSON LOADING
# =============================================================================

Load Invoice Json
    [Documentation]    Reads a JSON file from ${DATA_DIR} and returns it as a dict.
    [Arguments]    ${filename}
    ${path}=    Set Variable    ${DATA_DIR}/${filename}
    ${raw}=     Get File        ${path}
    ${data}=    Evaluate        json.loads($raw)    json
    RETURN    ${data}



# =============================================================================
# FIELD OVERRIDES
# =============================================================================

Override Placeholder Fields
    [Documentation]
    ...    Replaces Series, Number, DateIssued, DistributionDetails.InternalDocumentId
    ...    with unique values and sets Issuer/CounterParty VATs from suite variables.
    [Arguments]    ${payload}

    ${new}=          Evaluate    copy.deepcopy($payload)    copy
    ${series}=       Generate Unique Series
    ${number}=       Generate Unique Number
    ${date_issued}=  Generate Iso Datetime
    ${guid}=         Evaluate    str(uuid.uuid4())    uuid

    Set To Dictionary    ${new}    Series       ${series}
    Set To Dictionary    ${new}    Number       ${number}
    Set To Dictionary    ${new}    DateIssued   ${date_issued}

    ${dist}=    Get From Dictionary    ${new}    DistributionDetails
    Set To Dictionary    ${dist}    InternalDocumentId    ${guid}
    Set To Dictionary    ${new}     DistributionDetails   ${dist}

    ${issuer}=    Get From Dictionary    ${new}    Issuer
    Set To Dictionary    ${issuer}    Vat    ${ISSUER_VAT}
    Set To Dictionary    ${new}       Issuer    ${issuer}

    ${cp}=    Get From Dictionary    ${new}    CounterParty
    Set To Dictionary    ${cp}     Vat    ${COUNTER_PARTY_VAT}
    Set To Dictionary    ${new}    CounterParty    ${cp}

    ${has_transporter}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${new}    Transporter
    IF    ${has_transporter}
    ${tr}=    Get From Dictionary    ${new}    Transporter
    Set To Dictionary    ${tr}     Vat    ${TRANSPORTER_VAT}
    Set To Dictionary    ${new}    Transporter    ${tr}
    END

    Set To Dictionary    ${new}    DocumentTypeCode    ${DocumentTypeCode}

    Log    Overrides: Series=${series} Number=${number} DateIssued=${date_issued} Guid=${guid}    INFO
    RETURN    ${new}

Override Distribution Dates
    [Documentation]    Sets DistributionDetails.dispatchDate and dispatchtime
    ...                to the current ISO datetime.
    [Arguments]    ${payload}

    ${new}=       Evaluate    copy.deepcopy($payload)    copy
    ${dispatch}=  Generate Iso Datetime

    ${dist}=    Get From Dictionary    ${new}    DistributionDetails
    Set To Dictionary    ${dist}    dispatchDate    ${dispatch}
    Set To Dictionary    ${dist}    dispatchtime    ${dispatch}
    Set To Dictionary    ${new}     DistributionDetails    ${dist}

    RETURN    ${new}

Override Payment Date
    [Documentation]    Sets ALL PaymentDate fields (PascalCase + camelCase + PaymentTerms) to current ISO datetime.
    [Arguments]    ${payload}

    ${new}=           Evaluate    copy.deepcopy($payload)    copy
    ${payment_date}=  Generate Iso Datetime

    ${pay}=    Get From Dictionary    ${new}    PaymentDetails
    # camelCase key (new)
    Set To Dictionary    ${pay}    paymentDate       ${payment_date}
    # PascalCase key (template placeholder)
    Set To Dictionary    ${pay}    PaymentDate       ${payment_date}

    # Fix PaymentTerms[*].PaymentDate placeholders
    ${terms}=    Get From Dictionary    ${pay}    PaymentTerms
    FOR    ${term}    IN    @{terms}
        Set To Dictionary    ${term}    PaymentDate    ${payment_date}
    END
    Set To Dictionary    ${pay}    PaymentTerms    ${terms}

    Set To Dictionary    ${new}    PaymentDetails    ${pay}

    RETURN    ${new}

# =============================================================================
# GENERATORS
# =============================================================================

Generate Unique Series
    ${stamp}=    Evaluate
    ...    __import__('datetime').datetime.now().strftime('%Y%m%d%H%M%S') + f"{__import__('datetime').datetime.now().microsecond // 1000:03d}"
    RETURN    S${stamp}

Generate Unique Number
    ${stamp}=    Evaluate
    ...    __import__('datetime').datetime.now().strftime('%y%m%d%H%M%S') + f"{__import__('datetime').datetime.now().microsecond // 1000:03d}"
    RETURN    ${stamp}

Generate Iso Datetime
    ${value}=    Evaluate
    ...    __import__('datetime').datetime.now().strftime('%Y-%m-%dT%H:%M:%S.') + f"{__import__('datetime').datetime.now().microsecond // 1000:03d}"
    RETURN    ${value}

# =============================================================================
# RESULT PERSISTENCE
# =============================================================================

Save Response Result
    [Documentation]    Appends a row to Results/results.csv and writes a
    ...                per-test JSON snapshot.
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
    ...                url=${url}    message=${message}
    ${snapshot_json}=  Evaluate    json.dumps($snapshot, indent=2, ensure_ascii=False)    json
    ${safe_ts}=        Replace String    ${ts}    :    -
    Create File
    ...    ${RESULTS_DIR}/${test_name}_${safe_ts}.json
    ...    ${snapshot_json}

    Log    Saved result row to ${csv_path}    INFO
