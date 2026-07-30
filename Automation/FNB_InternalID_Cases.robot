*** Test Cases ***
TC 01 - Fire All With 1sec Interval
    [Tags]             uniqueness    case_A
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case A — 1sec interval μεταξύ requests    console=yes
    Log    🔑 Run Prefix: ${RUN_PREFIX}    console=yes

    # ── Χτίσε όλα τα payloads ──────────────────────
    # TC_A_01 → Series A, InternalId 1, v1, number 1
    ${p1}=    Build Payload    v1    A    A    1    number=999001

    # TC_A_02 → Series A, InternalId 1, v1, number 1 (ΙΔΙΟ με A_01 → 409 duplicate)
    ${p2}=    Build Payload    v1    A    A    1    number=999001

    # TC_A_03 → Series A, InternalId 2, v1, number 2 (ίδιο Series A → 409)
    ${p3}=    Build Payload    v1    A    A    2    number=999002

    # TC_A_04 → Series A, InternalId 2, v2, number 2 (ίδιο Series A → 409)
    ${p4}=    Build Payload    v2    A    A    2    number=999002

    # TC_A_05 → Series B, InternalId 2, v2 (ΔΙΑΦΟΡΕΤΙΚΟ series → 201)
    ${p5}=    Build Payload    v2    A    B    2    number=999002

    # TC_A_06 → Series C, InternalId 1, v1 (ΔΙΑΦΟΡΕΤΙΚΟ series → 201)
    ${p6}=    Build Payload    v1    A    C    1    number=999001

    # ── Fire όλα με 1sec διάφορα ────────────────────
    ${proc1}=    Fire Request Async    ${p1}    NONE    TC_A_01
    Sleep    1s

    ${proc2}=    Fire Request Async    ${p2}    NONE    TC_A_02
    Sleep    500ms

    ${proc3}=    Fire Request Async    ${p3}    NONE    TC_A_03
    Sleep    500ms

    ${proc4}=    Fire Request Async    ${p4}    NONE    TC_A_04
    Sleep    500ms

    ${proc5}=    Fire Request Async    ${p5}    NONE    TC_A_05
    Sleep    500ms

    ${proc6}=    Fire Request Async    ${p6}    NONE    TC_A_06

    # ── Περίμενε να τελειώσουν όλα ─────────────────
    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()
    Evaluate    $proc3.wait()
    Evaluate    $proc4.wait()
    Evaluate    $proc5.wait()
    Evaluate    $proc6.wait()

    # ── Έλεγξε αποτελέσματα ────────────────────────
    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_A_01    201
    Get Async Result    TC_A_02    409
    Get Async Result    TC_A_03    409
    Get Async Result    TC_A_04    409
    Get Async Result    TC_A_05    201
    Get Async Result    TC_A_06    201

    Log    ✅ Case A ολοκληρώθηκε!    console=yes

TC 02 - Fire All With 500ms Interval
    [Tags]    case_b_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case B — FAKE_IAPR_TIMEOUT    console=yes

    # TC_B_01 → Series A, Id 1, v1 → 408 IAPR Timeout
    ${p1}=    Build Payload    v1    B    A    1    number=999001

    # TC_B_02 → Series A, Id 2, v1 → 201 (μετά το timeout)
    ${p2}=    Build Payload    v1    B    A    2    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_IAPR_TIMEOUT    TC_B_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    NONE    TC_B_02

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_B_01    408
    Get Async Result    TC_B_02    201

    Log    ✅ Case B ολοκληρώθηκε!    console=yes
TC 03 - Fire All With 500ms Interval
    [Tags]    case_c_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case C — FAKE_IAPR_DELAYED_TIMEOUT    console=yes

    # TC_C_01 → Series A, Id 1, v1 → 408 Delayed Timeout
    ${p1}=    Build Payload    v1    C    A    1    number=999001

    # TC_C_02 → Series B, Id 1, v1 → 201
    ${p2}=    Build Payload    v1    C    B    1    number=999001

    # TC_C_03 → Series A, Id 2, v1 → 201
    ${p3}=    Build Payload    v1    C    A    2    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_IAPR_DELAYED_TIMEOUT    TC_C_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    NONE    TC_C_02
    Sleep    120s

    ${proc3}=    Fire Request Async    ${p3}    NONE    TC_C_03

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()
    Evaluate    $proc3.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_C_01    408
    Get Async Result    TC_C_02    201
    Get Async Result    TC_C_03    201

    Log    ✅ Case C ολοκληρώθηκε!    console=yes
TC 04 - Fire All With 500ms Interval
    [Tags]    case_d_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case D — FAKE_IAPR_DELAYED    console=yes

    # TC_D_01 → Series A, Id 1, v1 → 201 (DELAYED επιστρέφει 201)
    ${p1}=    Build Payload    v1    D    A    1    number=999001

    # TC_D_02 → Series A, Id 1, v2 → 409 (duplicate του D_01)
    ${p2}=    Build Payload    v2    D    A    1    number=999001

    # TC_D_03 → Series A, Id 2, v2 → 201 (νέο InternalId)
    ${p3}=    Build Payload    v2    D    A    2    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_IAPR_TIMEOUT    TC_D_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    FAKE_IAPR_DELAYED_TIMEOUT    TC_D_02
    Sleep    120s

    ${proc3}=    Fire Request Async    ${p3}    NONE    TC_D_03

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()
    Evaluate    $proc3.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_D_01    408
    Get Async Result    TC_D_02    408
    Get Async Result    TC_D_03    201

    Log    ✅ Case D ολοκληρώθηκε!    console=yes
TC 05 - Fire All With 500ms Interval
    [Tags]    case_e_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case E — FAKE_IAPR_VALIDATION_ERROR    console=yes

    # TC_E_01 → Series A, Id 1, v1 → 400 Validation Error
    ${p1}=    Build Payload    v1    E    A    1    number=999001

    # TC_E_02 → Series A, Id 2, v1 → 400 Validation Error
    ${p2}=    Build Payload    v1    E    A    2    number=999001

    # TC_E_03 → Series B, Id 1, v2 → 201
    ${p3}=    Build Payload    v2    E    B    1    number=999001

    # TC_E_04 → Series A, Id 2, v2 → 201
    ${p4}=    Build Payload    v2    E    A    3    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_IAPR_VALIDATION_ERROR    TC_E_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    FAKE_IAPR_VALIDATION_ERROR    TC_E_02
    Sleep    500ms

    ${proc3}=    Fire Request Async    ${p3}    NONE    TC_E_03
    Sleep    500ms

    ${proc4}=    Fire Request Async    ${p4}    NONE    TC_E_04

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()
    Evaluate    $proc3.wait()
    Evaluate    $proc4.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_E_01    400    Aade Validation Error
    Get Async Result    TC_E_02    400    Aade Validation Error
    Get Async Result    TC_E_03    201
    Get Async Result    TC_E_04    201

    Log    ✅ Case E ολοκληρώθηκε!    console=yes
TC 06 - Fire All With 500ms Interval
    [Tags]    case_f_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case F — FAKE_IAPR_VALIDATION_ERROR   console=yes

    # TC_F_01 → Series A, Id 1, v1 → 500 Elise Error
    ${p1}=    Build Payload    v1    F    A    1    number=999001

    # TC_F_02 → Series A, Id 2, v1 → 201 (μετά το error)
    ${p2}=    Build Payload    v1    F    A    2    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_IAPR_VALIDATION_ERROR    TC_F_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    NONE    TC_F_02

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_F_01    400
    Get Async Result    TC_F_02    201

    Log    ✅ Case F ολοκληρώθηκε!    console=yes
TC 07 - Fire All With 500ms Interval
    [Tags]    case_g_fire
    Generate Run Series Prefix
    Log    🚀 Ξεκινάει Case G — FAKE_ELISE_SAVE_DOCUMENT_ERROR    console=yes

    # TC_G_01 → Series A, Id 1, v1 → 500 Elise Error
    ${p1}=    Build Payload    v1    G    A    1    number=999001

    # TC_G_02 → Series B, Id 1, v1 → 201
    ${p2}=    Build Payload    v1    G    B    1    number=999001

    # TC_G_03 → Series A, Id 1, v2 → 201
    ${p3}=    Build Payload    v2    G    A    1    number=999001

    ${proc1}=    Fire Request Async    ${p1}    FAKE_ELISE_SAVE_DOCUMENT_ERROR    TC_G_01
    Sleep    500ms

    ${proc2}=    Fire Request Async    ${p2}    NONE    TC_G_02
    Sleep    120s

    ${proc3}=    Fire Request Async    ${p3}    NONE    TC_G_03

    Log    ⏳ Περιμένει όλα τα responses...    console=yes
    Evaluate    $proc1.wait()
    Evaluate    $proc2.wait()
    Evaluate    $proc3.wait()

    Log    📊 Αποτελέσματα:    console=yes
    Get Async Result    TC_G_01    500    Could not accept document. Please resend.
    Get Async Result    TC_G_02    201
    Get Async Result    TC_G_03    201

    Log    ✅ Case G ολοκληρώθηκε!    console=yes

*** Settings ***
Documentation    Case A — Fire all requests with 1sec interval
Library          OperatingSystem
Library          RequestsLibrary
Library          Collections
Library          DateTime
Library          String
Variables        ${EXECDIR}/config/credentials.py

*** Variables ***
${BASE_URL}      ${UAT_API}
${API_KEY}       ${EINVOICE_API_KEY}
${VAT1}          ${ISSUER_VAT}
${RUN_PREFIX}    ${EMPTY}

*** Keywords ***
Generate Run Series Prefix
    ${now}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    Set Suite Variable    ${RUN_PREFIX}    ${now}

Build Series
    [Arguments]    ${case_letter}    ${relative_series}
    RETURN    ${RUN_PREFIX}_${case_letter}_${relative_series}

Build Payload
    [Arguments]    ${version}    ${case_letter}    ${relative_series}    ${internal_id}    ${number}=999001
    ${full_series}=    Build Series    ${case_letter}    ${relative_series}
    ${payload_file}=   Set Variable If    '${version}' == 'v1'
    ...    Automation/Data/8.6_Debit_FNB_Internalv1.json
    ...    Automation/Data/8.6_Debit_FNB_Internalv2.json
    ${payload_str}=    Get File    ${payload_file}
    ${now}=            Get Current Date    result_format=%Y-%m-%dT%H:%M:%S
    ${payload_str}=    Replace String    ${payload_str}    SERIES_PLACEHOLDER       ${full_series}
    ${payload_str}=    Replace String    ${payload_str}    INTERNAL_ID_PLACEHOLDER  ${internal_id}
    ${payload_str}=    Replace String    ${payload_str}    DATE_PLACEHOLDER         ${now}
    ${payload_str}=    Replace String    ${payload_str}    VAT_PLACEHOLDER          ${VAT1}
    ${payload_str}=    Replace String    ${payload_str}    NUMBER_PLACEHOLDER       ${number}
    RETURN    ${payload_str}

Fire Request Async
    [Arguments]    ${payload_str}    ${erp_value}    ${label}
    ${python}=    Evaluate    __import__('sys').executable
    ${result_file}=    Set Variable    C:/tmp/${label}_result.txt
    ${payload_file}=   Set Variable    C:/tmp/${label}_payload.json
    Create File    ${payload_file}    ${payload_str}
    ${p}=    Evaluate
    ...    __import__('subprocess').Popen([r'${python}', '-c', "import requests; r=requests.post('${BASE_URL}/Invoice/json', data=open(r'${payload_file}').read(), headers={'Content-Type':'application/json','apikey':'${API_KEY}','erp':'${erp_value}'}); open(r'${result_file}','w').write(str(r.status_code)+'SPLIT'+r.text)"])
    Log    🔥 ${label} fired! (ERP: ${erp_value})    console=yes
    RETURN    ${p}

Get Async Result
    [Arguments]    ${label}    ${expected_status}    ${expected_message}=${EMPTY}
    ${result_file}=    Set Variable    C:/tmp/${label}_result.txt
    Wait Until Created    ${result_file}    timeout=300s
    ${content}=         Get File    ${result_file}
    # Χρήση Python split αντί για Robot Split String
    ${status_code}=    Evaluate    r'${content}'.split('SPLIT')[0]
    ${body}=           Evaluate    r'${content}'.split('SPLIT')[1]
    Log    ${label} → Status: ${status_code}    console=yes
    Log    ${label} → Body: ${body}    console=yes
    Should Be Equal As Strings    ${status_code}    ${expected_status}
    ...    msg=${label} expected ${expected_status} but got ${status_code}
    Run Keyword If    '${expected_message}' != '${EMPTY}'
    ...    Should Contain    ${body}    ${expected_message}
    Log    ✅ ${label} PASS    console=yes

