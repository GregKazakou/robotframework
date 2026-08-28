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


# ── Συσχέτιση παραστατικών μέσω deliveryNoteMarks ↔ multipleConnectedMarks ────
#    Ο provider χαρτογραφεί το input πεδίο deliveryNoteMarks στο myDATA XML
#    στοιχείο multipleConnectedMarks. Οι έλεγχοι κατεβάζουν το /aade XML και
#    επαληθεύουν ότι τα marks συσχετίστηκαν σωστά.
DN LINK - three 9.3 delivery notes linked into one 1.1
    [Template]    NONE
    [Tags]        invoice    deliverynote    correlation
    # 1) Έκδοση 3 δελτίων αποστολής 9.3 — κρατάμε τα marks
    @{dn_marks}=    Create List
    FOR    ${i}    IN RANGE    3
        ${n}=      Evaluate    ${i} + 1
        ${dn}=     api.Load Template    9.3_Sales_20lines
        ${dn}=     api.Apply Unique Fields    ${dn}    DN
        ${dn}=     api.Set Party Vats    ${dn}    ${ISSUER_VAT}    ${COUNTERPARTY_TIN}
        ${res}=    Send Example    9.3 delivery note #${n}    ${EP_INVOICE}    ${dn}    201    require=mark
        Append To List    ${dn_marks}    ${res.mark}
    END
    Log    3 delivery-note marks: ${dn_marks}    INFO

    # 2) Έκδοση ενός 1.1 με τα 3 marks στο deliveryNoteMarks
    ${inv}=    api.Load Template    1.1_B2B
    ${inv}=    api.Apply Unique Fields    ${inv}    INV
    ${inv}=    api.Set Party Vats    ${inv}    ${ISSUER_VAT}    ${COUNTERPARTY_TIN}
    ${inv}=    api.Set Delivery Note Marks    ${inv}    ${dn_marks}
    ${inv_res}=    Send Example    1.1 linked to 3 delivery notes    ${EP_INVOICE}    ${inv}    201    require=mark

    # 3) Κατέβασμα του AADE XML του 1.1 και επαλήθευση multipleConnectedMarks
    ${xml}=    api.Fetch Aade Xml    ${inv_res.url}
    ${note}=   api.Assert Connected Marks    ${xml}    ${dn_marks}
    Log    ${note}    INFO

DN LINK - one 9.3 delivery note linked to three 1.1 invoices
    [Template]    NONE
    [Tags]        invoice    deliverynote    correlation
    # 1) Έκδοση 3 τιμολογίων 1.1 — κρατάμε τα marks
    @{inv_marks}=    Create List
    FOR    ${i}    IN RANGE    3
        ${n}=      Evaluate    ${i} + 1
        ${inv}=    api.Load Template    1.1_B2B
        ${inv}=    api.Apply Unique Fields    ${inv}    INV
        ${inv}=    api.Set Party Vats    ${inv}    ${ISSUER_VAT}    ${COUNTERPARTY_TIN}
        ${res}=    Send Example    1.1 invoice #${n}    ${EP_INVOICE}    ${inv}    201    require=mark
        Append To List    ${inv_marks}    ${res.mark}
    END
    Log    3 invoice marks: ${inv_marks}    INFO

    # 2) Έκδοση ενός 9.3 με τα 3 marks των 1.1 στο deliveryNoteMarks
    ${dn}=     api.Load Template    9.3_Sales_20lines
    ${dn}=     api.Apply Unique Fields    ${dn}    DN
    ${dn}=     api.Set Party Vats    ${dn}    ${ISSUER_VAT}    ${COUNTERPARTY_TIN}
    ${dn}=     api.Set Delivery Note Marks    ${dn}    ${inv_marks}
    ${dn_res}=    Send Example    9.3 linked to 3 invoices    ${EP_INVOICE}    ${dn}    201    require=mark

    # 3) Επαλήθευση συσχέτισης στο AADE XML του 9.3
    ${xml}=    api.Fetch Aade Xml    ${dn_res.url}
    ${note}=   api.Assert Connected Marks    ${xml}    ${inv_marks}
    Log    ${note}    INFO


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
