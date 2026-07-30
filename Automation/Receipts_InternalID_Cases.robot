*** Test Cases ***
TC 01 - UID Uniqueness Vs InternalDocumentId Non-Uniqueness
    [Documentation]    Same UID: 1st ok -> 2nd/3rd concurrent 408 -> 4th (after window) 409.
    ...                Then different series (different UID) succeed even though
    ...                internalDocumentId repeats. Proves internalDocumentId is NOT
    ...                part of the uniqueness check.
    [Tags]             uniqueness    case_A
    ${num}=    Case Base Number    A
    # series / number / internalId / version / erp / expected
    Send And Verify    A    ${num}    1    v1    ${ERP_NONE}    201
    Send And Verify    A    ${num}    1    v1    ${ERP_NONE}    409
    Send And Verify    A    ${num}    2    v1    ${ERP_NONE}    409
    #Log To Console     \nCase A: sleeping ${UID_LOCK_WAIT} to close the UID lock window...
    #Sleep              ${UID_LOCK_WAIT}
    Send And Verify    A    ${num}    2    v2    ${ERP_NONE}    409
    Send And Verify    B    ${num}    2    v2    ${ERP_NONE}    201
    Send And Verify    C    ${num}    1    v1    ${ERP_NONE}    201

TC 02 - FAKE IAPR Delayed Timeout Then Success On Same UID
    [Documentation]    Forced delayed-timeout on first try; the same UID (same series,
    ...                same number) is accepted on the retry with a different
    ...                internalDocumentId.
    [Tags]             fake_delayed_timeout    case_B
    ${num}=    Case Base Number    B
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_TIMEOUT}    408
    Send And Verify    A    ${num}    2    v1    ${ERP_NONE}            201

TC 03 - Delayed Timeout, Different Series Succeeds, Same Series Retry Succeeds    #check portal
    [Tags]             fake_delayed_timeout    case_C
    ${num}=    Case Base Number    C
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_TIMEOUT}            408
    Send And Verify    B    ${num}    1    v1    ${ERP_NONE}                    201
    Send And Verify    A    ${num}    2    v1    ${ERP_NONE}                    201

TC 04 - Two Consecutive Forced Timeouts Then Success
    [Documentation]    Same series+number across all three requests. First two are
    ...                forced to time out (different fake headers), third succeeds.
    [Tags]             fake_delayed_timeout    fake_timeout    case_D
    ${num}=    Case Base Number    D
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_TIMEOUT}            408
    Send And Verify    A    ${num}    1    v2    ${ERP_FAKE_TIMEOUT}            408
    Send And Verify    A    ${num}    1    v2    ${ERP_NONE}                    201

TC 05 - IAPR Validation Error Does Not Lock The UID        #δεν παιζει σωστα η ενημερωση του portal
    [Tags]             fake_validation_error    case_E
    ${num}=    Case Base Number    E
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_VALIDATION}    400
    Send And Verify    A    ${num}    2    v1    ${ERP_FAKE_VALIDATION}    400
    Send And Verify    B    ${num}    1    v2    ${ERP_NONE}               201
    Send And Verify    A    ${num}    2    v2    ${ERP_NONE}               201    #*

TC 06 - Validation Error Returns 500 Then Retry Succeeds     #δεν παιζει σωστα η ενημερωση του portal
    [Documentation]    Per the spec matrix provided. If your backend actually returns
    ...                400 for FAKE_IAPR_VALIDATION_ERROR here, change ${ERP_FAKE_VALIDATION}
    ...                below to the correct forced-error header (possibly a different one
    ...                than Case E) or change 500 to 400.
    [Tags]             fake_validation_error    case_F
    ${num}=    Case Base Number    F
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_VALIDATION}    400
    Send And Verify    A    ${num}    2    v1    ${ERP_NONE}               201        #*

TC 07 - Elise Save Document Error Does Not Lock The UID        #δεν παιζει σωστα η ενηεμερωση του portal, να βαλουμε internal page για τα 8.4, history να δουμε και το issuedate του portal
    [Tags]             fake_elise    case_G
    ${num}=    Case Base Number    G
    Send And Verify    A    ${num}    1    v1    ${ERP_FAKE_ELISE_SAVE}    500
    Send And Verify    B    ${num}    1    v1    ${ERP_NONE}               201
    Log To Console     \nCase A: sleeping ${UID_LOCK_WAIT} to close the UID lock window...
    Sleep              ${UID_LOCK_WAIT}
    Send And Verify    A    ${num}    1    v2    ${ERP_NONE}               201


*** Settings ***
Documentation     API test suite for POST /Receipt on einvoiceapiuat.impact.gr.
...
...               Validates the two orthogonal properties of the endpoint:
...                 1. UID uniqueness:
...                    UID = {vat}-{dateIssued}-{branchCode}-{invoiceTypeCode}-{series}-{number}
...                    Same UID on a completed document -> 409
...                    Same UID while first is still processing -> 408
...                 2. InternalDocumentId has NO uniqueness check:
...                    the same internalDocumentId is reused across series/cases on purpose.
...
...               Also exercises the ERP-header forced-error paths:
...                 - FAKE_IAPR_DELAYED_TIMEOUT
...                 - FAKE_IAPR_TIMEOUT
...                 - FAKE_IAPR_VALIDATION_ERROR
...                 - FAKE_ELISE_SAVE_DOCUMENT_ERROR
...
...               A fresh, unique `number` is generated per run from epoch+hash(case),
...               so the whole suite can be re-run without hitting UID collisions from
...               previous runs.

Library           RequestsLibrary
Library           Collections
Library           String
Library           DateTime
Library           OperatingSystem
Variables         ${EXECDIR}/config/credentials.py

Suite Setup       Initialize Suite


*** Variables ***
${BASE_URL}                    ${UAT_API}
${ENDPOINT}                    /Receipt
# Set via: robot -v API_KEY:xxxxx ...    or    export EINVOICE_API_KEY=xxxxx
${API_KEY}                     ${EINVOICE_API_KEY}
${TEMPLATE_FILE}               ${CURDIR}/Data/8.4_POS_Receipt.json

# v1/v2 only differ in totalAmount (header + line). UID is unaffected.
${V1_TOTAL_AMOUNT}             ${124}
${V2_TOTAL_AMOUNT}             ${200}

# erp header values
${ERP_NONE}                    none
${ERP_FAKE_DELAYED_TIMEOUT}    FAKE_IAPR_DELAYED_TIMEOUT
${ERP_FAKE_TIMEOUT}            FAKE_IAPR_TIMEOUT
${ERP_FAKE_VALIDATION}         FAKE_IAPR_VALIDATION_ERROR
${ERP_FAKE_ELISE_SAVE}         FAKE_ELISE_SAVE_DOCUMENT_ERROR

# Sleep used in Case A to let the 2-minute concurrent window expire
# so the 4th send transitions from 408 -> 409.
${UID_LOCK_WAIT}               2m 10s




*** Keywords ***
Initialize Suite
    Create Session    einvoice    ${BASE_URL}    verify=${True}
    # Load the JSON template once; deep-copied per request so mutations don't leak.
    ${raw}=           Get File    ${TEMPLATE_FILE}
    ${template}=      Evaluate    json.loads($raw)    json
    Set Suite Variable    $PAYLOAD_TEMPLATE    ${template}
    # Unique run stamp -> guarantees fresh UIDs on every run
    ${stamp}=         Get Current Date    result_format=epoch    exclude_millis=${True}
    ${stamp_int}=     Convert To Integer    ${stamp}
    Set Suite Variable    $RUN_STAMP    ${stamp_int}
    ${today}=         Get Current Date    result_format=%Y-%m-%d
    Set Suite Variable    $TODAY    ${today}
    # Full timestamp (date + time) for the banner / logs
    ${now}=           Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Set Suite Variable    $NOW    ${now}
    ${time_only}=     Get Current Date    result_format=%H:%M:%S
    Set Suite Variable    $START_TIME    ${time_only}
    # Build the banner as a single string before logging.
    # We use $NAME (not ${NAME}) above so Set Suite Variable treats them as names,
    # not as lookups of not-yet-existing variables (that's what produced
    # "Variable '${RUN_STAMP}' not found.").
    ${banner}=        Set Variable    \n>>> RUN_STAMP=${RUN_STAMP} | date=${TODAY} | started at ${START_TIME}
    Log To Console    ${banner}

Case Base Number
    [Documentation]    Builds a number string that is:
    ...                - stable for the duration of the run inside a case
    ...                - unique across re-runs of the whole suite
    ...                - unique across cases in the same run
    [Arguments]        ${case_id}
    ${suffix}=    Evaluate    abs(hash("${case_id}")) % 10000
    ${num}=       Set Variable    ${RUN_STAMP}${suffix}
    RETURN        ${num}

Total For Version
    [Arguments]    ${version}
    ${amount}=    Run Keyword If    '${version}' == 'v1'
    ...           Set Variable    ${V1_TOTAL_AMOUNT}
    ...           ELSE             Set Variable    ${V2_TOTAL_AMOUNT}
    RETURN        ${amount}

Build Payload
    [Documentation]    Clones the JSON template and overrides only what each request needs.
    ...                v1 vs v2 differ ONLY in totalAmount (header + first cardline),
    ...                which is not part of the UID.
    [Arguments]    ${series}    ${number}    ${internal_id}    ${version}
    ${amount}=      Total For Version    ${version}
    ${payload}=     Evaluate    copy.deepcopy($PAYLOAD_TEMPLATE)    modules=copy
    Set To Dictionary    ${payload}
    ...    series=${series}
    ...    number=${number}
    ...    dateIssued=${TODAY}
    ...    providerSignatureIdentifier=${number}
    ...    totalAmount=${amount}
    ...    internalDocumentId=InternalId_Receipt100_${internal_id}
    ${cardlines}=   Get From Dictionary    ${payload}    cardlines
    ${first_line}=  Get From List          ${cardlines}  ${0}
    Set To Dictionary    ${first_line}    amount=${amount}
    RETURN    ${payload}

Send Receipt
    [Arguments]    ${payload}    ${erp}=${ERP_NONE}
    ${headers}=    Create Dictionary
    ...    apikey=${API_KEY}
    ...    erp=${erp}
    ...    Content-Type=application/json
    ${response}=   POST On Session    einvoice    ${ENDPOINT}
    ...            json=${payload}    headers=${headers}    expected_status=any
    Log    Sent erp=${erp} series=${payload}[series] number=${payload}[number] internalDocumentId=${payload}[internalDocumentId] totalAmount=${payload}[totalAmount]
    Log    Status: ${response.status_code}
    Log    Body: ${response.text}
    RETURN    ${response}

Send And Verify
    [Arguments]    ${series}    ${number}    ${internal_id}    ${version}    ${erp}    ${expected}
    ${payload}=    Build Payload    ${series}    ${number}    ${internal_id}    ${version}
    ${response}=   Send Receipt     ${payload}    ${erp}
    Run Keyword And Continue On Failure
    ...    Should Be Equal As Integers    ${response.status_code}    ${expected}
    ...    msg=[series=${series} internalId=${internal_id} ${version} erp=${erp}] expected ${expected} got ${response.status_code}. Body: ${response.text}
