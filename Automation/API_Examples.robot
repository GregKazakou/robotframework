*** Settings ***
Documentation     Playground / harness για γρήγορα API παραδείγματα.
...
...               ΣΚΟΠΟΣ: να προσθέτεις και να τεστάρεις νέα JSON παραδείγματα
...               εύκολα — είτε με ένα αρχείο .json + μία γραμμή, είτε inline.
...
...               ─────────────────────────────────────────────────────────
...               ΤΡΟΠΟΣ 1 — Παράδειγμα από αρχείο (data-driven)
...               ─────────────────────────────────────────────────────────
...               1. Βάλε το .json σου στο φάκελο Automation/Data/
...               2. Πρόσθεσε ΜΙΑ γραμμή στο "*** Test Cases ***" με στήλες:
...                     <Όνομα test>    <json>    <endpoint>    <expected>    <require>
...                  π.χ.:
...                     My new invoice    my_example.json    ${EP_INVOICE}    201    mark
...                  - <require> (προαιρετικό): πεδία που πρέπει να γυρίσει το
...                    response μη-κενά, χωρισμένα με κόμμα (π.χ. mark ή
...                    signature,input). Άφησέ το κενό αν δεν θέλεις έλεγχο.
...
...               Κάθε run εφαρμόζει αυτόματα μοναδικά Series/Number/dateIssued/
...               GUID (όπου υπάρχουν στο payload), ώστε να ξανατρέχει χωρίς
...               σφάλμα διπλού παραστατικού.
...
...               ─────────────────────────────────────────────────────────
...               ΤΡΟΠΟΣ 2 — Inline παράδειγμα (χτίζεις το JSON μέσα στο test)
...               ─────────────────────────────────────────────────────────
...               Δες το test "INLINE - minimal signpos example" πιο κάτω:
...               ορίζει [Template] NONE και χτίζει το payload με Create
...               Dictionary ή με raw JSON string (api.Parse Json).
...
...               ─────────────────────────────────────────────────────────
...               ΕΚΤΕΛΕΣΗ
...               ─────────────────────────────────────────────────────────
...               Όλα:            robot Automation/API_Examples.robot
...               Ένα μόνο:       robot -t "1.1 B2B*" Automation/API_Examples.robot
...               Ανά endpoint:   robot -i invoice Automation/API_Examples.robot
...
...               Στο report κάθε test δείχνει mark + clickable portal URL.

Library           helpers.py    WITH NAME    api
Library           Collections
Library           OperatingSystem
Library           DateTime
Variables         ${EXECDIR}/config/credentials.py

Suite Setup       Setup Example Client
Test Template     Run Example From File


*** Variables ***
${BASE_URL}       ${UAT_API}
${API_KEY}        ${EINVOICE_API_KEY}

# Endpoint shortcuts — πρόσθεσε κι άλλα εδώ αν χρειαστεί
${EP_INVOICE}          /Invoice/json
${EP_RECEIPT}          /Receipt
${EP_SIGNPOS}          /PosTransactions/signpos
${EP_VALIDATE}         /PosTransactions/validate
${EP_UPDATE_PAYMENT}   /Invoice/updatePayment


*** Test Cases ***                     JSON_FILE                              ENDPOINT         EXPECTED    REQUIRE
# ── Έτοιμα παραδείγματα (αντέγραψε μία γραμμή για νέο) ─────────────────────────
1.1 B2B invoice Generic                1.1_B2B.json                           ${EP_INVOICE}    201         mark
    [Tags]    invoice    b2b
8.4 POS receipt Generic                       8.4_POS_Receipt.json                   ${EP_RECEIPT}    201         mark
    [Tags]    receipt    pos
11.1 retail sales Generic                      11.1_FNB_Retail_Sales_Receipt.json     ${EP_INVOICE}    201         mark
    [Tags]    invoice    retail
8.6 debit FNB form Generic                      8.6_Debit_FNB_Form.json                ${EP_INVOICE}    201         mark
    [Tags]    invoice    fnb

1.1 B2G invoice Generic                     1.1_B2G.json                           ${EP_INVOICE}    201         mark
    [Tags]    invoice    b2g    
# ↓↓↓ Πρόσθεσε τα δικά σου παραδείγματα εδώ (json στο Automation/Data/) ↓↓↓


# ── Fuel invoice: myDATA 229 ανοχή απόκλισης ΦΠΑ ανά γραμμή ───────────────────
#    Έλεγχος per-line ≤ 1.00 EUR (declared vatAmount vs net × συντελεστή).
#    [Template] NONE γιατί το negative test επιβεβαιώνει ΕΙΔΙΚΑ το σφάλμα 229,
#    όχι οποιοδήποτε 400.
FUEL - per-line VAT deviation 1.01 EUR -> 400 (myDATA 229)
    [Template]    NONE
    [Tags]        invoice    fuel    negative
    ${res}=    Run Example From File    1.1_B2B_FUEL_FAIL.json    ${EP_INVOICE}    400
    Should Contain    ${res.raw_text}    <code>229</code>
    ...    msg=Περίμενα myDATA ValidationError 229 (per-line vatAmount απόκλιση), got: ${res.message}
    Should Contain    ${res.message}    invoice line: 3
    ...    msg=Η απόκλιση 1.01 EUR είναι στη γραμμή 3 (fuelCode 30)

FUEL - per-line VAT deviation 1.00 EUR -> 201 (within tolerance)
    [Template]    NONE
    [Tags]        invoice    fuel
    Run Example From File    1.1_B2B_FUEL_PASS.json    ${EP_INVOICE}    201    require=mark


# ── Inline παράδειγμα (χτίζεις το JSON στο test, χωρίς νέο αρχείο) ─────────────
#    Φορτώνει ένα template και το πειράζει inline με Deep Merge. Έτσι βλέπεις
#    πώς να αλλάζεις μόνο ό,τι θες, χωρίς να αντιγράφεις όλο το JSON.
INLINE - signpos via template + overrides
    [Template]    NONE
    [Tags]        inline    signpos
    ${vat}=       Evaluate    round(124 - 124/1.13, 2)
    ${net}=       Evaluate    round(124 - ${vat}, 2)
    ${base}=      api.Load Template    signpos
    ${over}=      Create Dictionary
    ...    issueDate=${TODAY}
    ...    invoiceTypeCode=8.4
    ...    identifier=${RUN_STAMP}INLINE
    ...    mark=${0}
    ...    paymentAmount=${124}
    ...    totalAmount=${124}
    ...    totalNetAmount=${net}
    ...    totalVatAmount=${vat}
    ...    terminalId=16000198
    ${payload}=   api.Deep Merge    ${base}    ${over}
    Send Example    inline signpos    ${EP_SIGNPOS}    ${payload}    200    require=signature,input


*** Keywords ***
Setup Example Client
    api.Configure Client    ${BASE_URL}    ${API_KEY}    ${120}
    ${today}=      Get Current Date    result_format=%Y-%m-%d
    Set Suite Variable    ${TODAY}    ${today}
    ${stamp}=      Get Current Date    result_format=epoch    exclude_millis=${True}
    ${stamp_int}=  Convert To Integer    ${stamp}
    Set Suite Variable    ${RUN_STAMP}    ${stamp_int}

Run Example From File
    [Documentation]    Data-driven entry point: φορτώνει το <json_name> από το
    ...                Automation/Data/, βάζει μοναδικά πεδία + το σωστό
    ...                Issuer/CounterParty VAT (από credentials) και το στέλνει.
    [Arguments]    ${json_name}    ${endpoint}    ${expected}    ${require}=${EMPTY}    ${unique}=${True}
    ${payload}=    api.Load Template    ${json_name}
    IF    ${unique}
        ${payload}=    api.Apply Unique Fields    ${payload}    EX
    END
    ${payload}=    api.Set Party Vats    ${payload}    ${ISSUER_VAT}    ${COUNTERPARTY_TIN}
    ${res}=    Send Example    ${json_name}    ${endpoint}    ${payload}    ${expected}    require=${require}
    RETURN    ${res}

Send Example
    [Documentation]    Ο πυρήνας: POST ${payload} στο ${endpoint}, έλεγχος
    ...                HTTP status + response body, και εμφάνιση portal URL
    ...                στο test message. Επιστρέφει bunch (π.χ. ${res.mark}).
    [Arguments]    ${label}    ${endpoint}    ${payload}    ${expected}    ${query}=${None}    ${require}=${EMPTY}    ${erp}=none
    ${res}=    api.Post To    ${endpoint}    ${payload}    ${erp}    ${query}
    ${actual}=    Set Variable    ${res}[status_code]

    Log To Console    \n[${endpoint}] ${label}: HTTP ${actual} | ${res}[summary]

    # 1) HTTP status
    Run Keyword And Continue On Failure
    ...    Should Be Equal As Integers    ${actual}    ${expected}
    ...    msg=${label} (${endpoint}): expected ${expected}, got ${actual} | ${res}[summary]

    # 2) Response body (success flag + required fields)
    Run Keyword And Continue On Failure
    ...    api.Verify Body    ${res}    ${expected}    ${require}

    # 3) Portal URL στο test message
    ${url}=    Set Variable    ${res}[url]
    IF    '${url}' != '${EMPTY}'
        Set Test Message    *HTML* <br>${label}: <a href="${url}">${url}</a>    append=${True}
    END

    ${bunch}=    Evaluate    type('R',(object,),$res)()    modules=builtins
    RETURN    ${bunch}
