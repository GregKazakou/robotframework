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
# POS receipts ζουν σε ΔΙΑΦΟΡΕΤΙΚΟ host απ' το invoice, και το path είναι πεζό.
${POS_BASE_URL}       https://einvoice-demo.s1ecos.gr
${ENDPOINTPOS}        /receipt
${API_KEY}            ${EINVOICE_API_KEY}
${ISSUER_VAT}          ${ISSUER_TIN}
${COUNTER_PARTY_VAT}  ${RECIPIENT_TIN}
${TRANSPORTER_VAT}    ${TRANSPORTER_TIN}
${DocumentTypeCode}   INVOICE
${DN_CHUNK_SIZE}      ${20}
${DN_TOTAL}           ${50}
${DN_SOURCE_JSON}     all_1000_items.json
${INV_SOURCE_JSON}    all_1000_items_1.1.json
${8.4_SOURCE_JSON}    8.4_POS_Receipt.json

*** Test Cases ***

1.1_B2B
    [Tags]    smoke
    Submit Invoice And Verify    1.1_B2B.json

1.1_B2B_DN
    [Tags]    smoke
    Submit Invoice And Verify    1.1_B2B_DN.json
    ...    Override Distribution Dates    Override Payment Date

# =============================================================================
# dateIssued format matrix — ένα test, μία γραμμή ανά μορφή.
# Στέλνει το ίδιο 8.4 POS payload στο POS endpoint (${ENDPOINTPOS}) με 8 μορφές
# ημερομηνίας, ώστε να δεις ΠΟΙΑ δέχεται το API.
#   γραμμή πράσινη = δεκτή μορφή (HTTP 201)
#   γραμμή κόκκινη = απορρίφθηκε — το response φαίνεται στο μήνυμα
# ΣΗΜ.: αν ΟΛΕΣ οι γραμμές κοκκινίζουν με το ίδιο σφάλμα (π.χ. "Summaries
# section is mandatory") τότε ΔΕΝ φταίει η ημερομηνία — φταίει το payload/
# endpoint. Δες το σχόλιο στο keyword "Submit Pos Date Format".
# =============================================================================

DateIssued Format Matrix
    [Tags]    datefmt
    [Template]    Submit Pos Date Format By Generator
    Generate Date Midnight                 # 1  current date T00:00:00
    Generate Local Now                     # 2  local time GR (+03:00/+02:00)
    Generate Utc Midnight Z                # 3  UTC T00:00:00Z
    Generate Utc Now Z                     # 4  UTC now Z
    Generate Date Midnight Utc Offset      # 5  current date T00:00:00+00:00
    Generate Date Midnight Athens Offset   # 6  current date T00:00:00+03:00    
    Generate Utc Now Offset                # 7  now +00:00
    Generate Now Plus3 Offset              # 8  now +03:00

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

Submit Pos Date Format
    [Documentation]    Loads the 8.4 POS payload, βάζει μοναδικά series/number/guid
    ...                και το ΔΟΘΕΝ dateIssued, μετά POST στο POS receipt endpoint
    ...                (${POS_BASE_URL}${ENDPOINTPOS}, ΟΧΙ στο invoice endpoint).
    ...
    ...                ΓΙΑΤΙ ΟΧΙ "Post Invoice And Verify":
    ...                (1) το receipt ζει σε άλλο host/path απ' το invoice.
    ...                (2) το invoice endpoint validάρει το POS σαν τιμολόγιο και
    ...                    ζητάει Summaries κ.λπ. (HTTP 400).
    ...                (3) το receipt response ΔΕΝ έχει status=SUBMITTED.
    [Arguments]    ${date_issued}    ${label}=pos_datefmt

    ${payload}=    Load Invoice Json                  ${8.4_SOURCE_JSON}
    ${payload}=    Override Pos Placeholder Fields    ${payload}    ${date_issued}
    Log    ${label}: dateIssued -> ${date_issued}    INFO    console=${True}

    ${headers}=    Create Dictionary    Content-Type=application/json    apikey=${API_KEY}
    Create Session    receipt    ${POS_BASE_URL}    headers=${headers}    verify=${True}
    ${response}=    POST On Session    receipt    ${ENDPOINTPOS}    json=${payload}
    ...             expected_status=any

    ${mark}=    Evaluate    ($response.json() if 'application/json' in $response.headers.get('Content-Type','') else {}).get('mark', '')
    Log    ${label}: dateIssued=${date_issued} -> HTTP ${response.status_code} mark=${mark} | ${response.text}
    ...    INFO    console=${True}
    Save Response Result    status_code=${response.status_code}    mark=${mark}
    ...    url=${EMPTY}    message=${response.status_code}    test_name=${label}

    Should Be Equal As Integers    ${response.status_code}    201
    ...    msg=HTTP ${response.status_code}: ${response.text}
    RETURN    ${response.status_code}

Submit Pos Date Format By Generator
    [Documentation]    Template row: τρέχει τον generator (π.χ. Generate Utc Now Z),
    ...                παίρνει το dateIssued και στέλνει το POS payload.
    [Arguments]    ${generator_kw}
    ${date_issued}=    Run Keyword    ${generator_kw}
    Submit Pos Date Format    ${date_issued}    ${generator_kw}

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
    Set To Dictionary    ${issuer}    Vat    ${ISSUER_TIN}
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

    Log    Overrides: Series=${series} Number=${number} DateIssued=${date_issued} Guid=${guid}    INFO
    RETURN    ${new}

Override Pos Placeholder Fields
    [Documentation]    Ελαφρύ override για το camelCase POS payload (series/number/
    ...                dateIssued/providerSignatureIdentifier/internalDocumentId).
    ...                Το dateIssued έρχεται από το test case (μία από τις 8 μορφές).
    [Arguments]    ${payload}    ${date_issued}

    ${new}=       Evaluate    copy.deepcopy($payload)    copy
    ${series}=    Generate Unique Series
    ${number}=    Generate Unique Number
    ${guid}=      Evaluate    str(uuid.uuid4())    uuid

    Set To Dictionary    ${new}    series                         ${series}
    Set To Dictionary    ${new}    number                         ${number}
    Set To Dictionary    ${new}    dateIssued                     ${date_issued}
    Set To Dictionary    ${new}    providerSignatureIdentifier    ${guid}
    Set To Dictionary    ${new}    internalDocumentId             ${guid}
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

# --- dateIssued format matrix (myDATA) ---------------------------------------
# 1) current date, midnight, χωρίς ζώνη            -> 2026-07-15T00:00:00
Generate Date Midnight
    ${value}=    Evaluate    __import__('datetime').datetime.now().strftime('%Y-%m-%dT00:00:00')
    RETURN    ${value}

# 2) τοπική ώρα του μηχανήματος (DST-aware, χωρίς tzdata) -> 2026-07-15T17:09:14+03:00
#    Χρησιμοποιεί astimezone() -> παίρνει τη ζώνη των Windows, ΔΕΝ θέλει zoneinfo/tzdata.
Generate Local Now
    ${value}=    Evaluate    __import__('datetime').datetime.now().astimezone().isoformat(timespec='seconds')
    RETURN    ${value}

# 3) UTC, midnight, με Z                           -> 2026-07-15T00:00:00Z
Generate Utc Midnight Z
    ${value}=    Evaluate    __import__('datetime').datetime.now(__import__('datetime').timezone.utc).strftime('%Y-%m-%dT00:00:00Z')
    RETURN    ${value}

# 4) UTC τώρα, με Z                                -> 2026-07-15T12:59:45Z
Generate Utc Now Z
    ${value}=    Evaluate    __import__('datetime').datetime.now(__import__('datetime').timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    RETURN    ${value}

# 5) current date, midnight, +00:00               -> 2026-07-15T00:00:00+00:00
Generate Date Midnight Utc Offset
    ${value}=    Evaluate    __import__('datetime').datetime.now().strftime('%Y-%m-%dT00:00:00+00:00')
    RETURN    ${value}

# 6) current date, midnight, +03:00               -> 2026-07-15T00:00:00+03:00
Generate Date Midnight Athens Offset
    ${value}=    Evaluate    __import__('datetime').datetime.now().strftime('%Y-%m-%dT00:00:00+03:00')
    RETURN    ${value}

# 7) τώρα, με +00:00                               -> 2026-07-15T12:59:45+00:00
Generate Utc Now Offset
    ${value}=    Evaluate    __import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(timespec='seconds')
    RETURN    ${value}

# 8) τώρα, με +03:00 (σταθερό offset)              -> 2026-07-15T15:59:45+03:00
Generate Now Plus3 Offset
    ${value}=    Evaluate    __import__('datetime').datetime.now(__import__('datetime').timezone(__import__('datetime').timedelta(hours=3))).isoformat(timespec='seconds')
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
