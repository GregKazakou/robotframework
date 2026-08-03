*** Settings ***
Documentation       Σενάρια API notifications για e-invoicing.
...
...                 ΚΑΛΥΠΤΕΙ: b2b_json, b2g_json, jsonxml, deliverynote, grcore, cancel.
...
...                 ΣΗΜΑΝΤΙΚΟ - ΤΙ ΕΠΑΛΗΘΕΥΕΙ ΚΑΙ ΤΙ ΟΧΙ
...                 Οι ειδοποιήσεις (email/SMS/PDF) είναι ΑΣΥΓΧΡΟΝΕΣ. Η απάντηση του API
...                 επιβεβαιώνει ΜΟΝΟ ότι το παραστατικό έγινε δεκτό και καταχωρήθηκε.
...                 ΔΕΝ επιβεβαιώνει ότι στάλθηκε ή παραδόθηκε email/SMS. Αυτή η suite
...                 ελέγχει την υποβολή· η πραγματική παράδοση επαληθεύεται χειροκίνητα
...                 (ή με mailbox/SMS API) - δες τη στήλη "Expected" στο log.
...
...                 ΡΥΘΜΙΣΗ (environment variables):
...                 UAT_API   π.χ. https://uat.example.gr/api/
...                 API_KEY   το APIKey header
...
...                 ΕΚΤΕΛΕΣΗ:
...                 robot -v UAT_API:https://uat.example.gr/api/ -v API_KEY:xxxx einvoicing_notifications.robot
...                 robot --include delay0 einvoicing_notifications.robot
...                 robot --include b2b_json einvoicing_notifications.robot

Library             RequestsLibrary
Library             Collections
Library             String
Library             resources/NotificationPayloads.py
Variables           ${EXECDIR}/config/credentials.py

Suite Setup         Initialise Notification Suite
Suite Teardown      Delete All Sessions


*** Variables ***
# --- σύνδεση & δεδομένα δοκιμής ---
# Οι τιμές έρχονται από το config/credentials.py (Variables import παραπάνω).
# Override ανά εκτέλεση με command line -v, π.χ. -v API_KEY:xxxx -v UAT_API:https://...
# UAT_API, API_KEY, ISSUER_TIN, COUNTERPARTY_TIN, VALID_EMAIL, INVALID_EMAIL,
# VALID_CELL, INVALID_CELL, INVOICE_SEED  ->  ορίζονται στο credentials.py

${SESSION}                  einv
${LAST_MARK}                ${EMPTY}


*** Test Cases ***
# =========================================================================
# 3.1  B2B JSON - πλήρες schema, όλα τα σενάρια υποστηρίζονται
# =========================================================================
TC1 B2B JSON - Method A - Delay 5
    [Tags]    b2b_json    methodA    delay5    email
    [Template]    Submit Notification Scenario
    b2b_json    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC2 B2B JSON - Method E - Delay 5
    [Tags]    b2b_json    methodE    delay5    email
    [Template]    Submit Notification Scenario
    b2b_json    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC3 B2B JSON - Method M - SMS only - Delay 5
    [Tags]    b2b_json    methodM    delay5    sms
    [Template]    Submit Notification Scenario
    b2b_json    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    5

TC4 B2B JSON - Method C - Email + SMS - Delay 5
    [Tags]    b2b_json    methodC    delay5    email    sms
    [Template]    Submit Notification Scenario
    b2b_json    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    5

TC5 B2B JSON - Method A - SendAsPdf - Delay 5
    [Tags]    b2b_json    methodA    delay5    pdf
    [Template]    Submit Notification Scenario
    b2b_json    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    5

TC1 B2B JSON - Method A - Delay 0
    [Tags]    b2b_json    methodA    delay0    email
    [Template]    Submit Notification Scenario
    b2b_json    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC2 B2B JSON - Method E - Delay 0
    [Tags]    b2b_json    methodE    delay0    email
    [Template]    Submit Notification Scenario
    b2b_json    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC3 B2B JSON - Method M - SMS only - Delay 0
    [Tags]    b2b_json    methodM    delay0    sms
    [Template]    Submit Notification Scenario
    b2b_json    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    0

TC4 B2B JSON - Method C - Email + SMS - Delay 0
    [Tags]    b2b_json    methodC    delay0    email    sms
    [Template]    Submit Notification Scenario
    b2b_json    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    0

TC5 B2B JSON - Method A - SendAsPdf - Delay 0
    [Tags]    b2b_json    methodA    delay0    pdf
    [Template]    Submit Notification Scenario
    b2b_json    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    0

# =========================================================================
# 3.2  B2G JSON - ίδιο schema με B2B
# =========================================================================
TC1 B2G - Method A - Delay 5
    [Tags]    b2g_json    methodA    delay5    email
    [Template]    Submit Notification Scenario
    b2g_json    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC2 B2G - Method E - Delay 5
    [Tags]    b2g_json    methodE    delay5    email
    [Template]    Submit Notification Scenario
    b2g_json    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC3 B2G - Method M - SMS only - Delay 5
    [Tags]    b2g_json    methodM    delay5    sms
    [Template]    Submit Notification Scenario
    b2g_json    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    5

TC4 B2G - Method C - Email + SMS - Delay 5
    [Tags]    b2g_json    methodC    delay5    email    sms
    [Template]    Submit Notification Scenario
    b2g_json    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    5

TC5 B2G - Method A - SendAsPdf - Delay 5
    [Tags]    b2g_json    methodA    delay5    pdf
    [Template]    Submit Notification Scenario
    b2g_json    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    5

TC1 B2G - Method A - Delay 0
    [Tags]    b2g_json    methodA    delay0    email
    [Template]    Submit Notification Scenario
    b2g_json    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC2 B2G - Method E - Delay 0
    [Tags]    b2g_json    methodE    delay0    email
    [Template]    Submit Notification Scenario
    b2g_json    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC3 B2G - Method M - SMS only - Delay 0
    [Tags]    b2g_json    methodM    delay0    sms
    [Template]    Submit Notification Scenario
    b2g_json    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    0

TC4 B2G - Method C - Email + SMS - Delay 0
    [Tags]    b2g_json    methodC    delay0    email    sms
    [Template]    Submit Notification Scenario
    b2g_json    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    0

TC5 B2G - Method A - SendAsPdf - Delay 0
    [Tags]    b2g_json    methodA    delay0    pdf
    [Template]    Submit Notification Scenario
    b2g_json    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    0

# =========================================================================
# 3.3  JSON+XML - PascalCase, μειωμένο schema
#      CustomerCellNumbers / NotificationDelay ΔΕΝ υπάρχουν στο αρχικό template.
# =========================================================================
TC1 JSON+XML - Method A - Delay 5
    [Tags]    jsonxml    methodA    delay5    email    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC2 JSON+XML - Method E - Delay 5
    [Tags]    jsonxml    methodE    delay5    email    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC3 JSON+XML - Method M - SMS only - Delay 5
    [Tags]    jsonxml    methodM    delay5    sms    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    5

TC4 JSON+XML - Method C - Email + SMS - Delay 5
    [Tags]    jsonxml    methodC    delay5    email    sms    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    5

TC5 JSON+XML - Method A - SendAsPdf - Delay 5
    [Tags]    jsonxml    methodA    delay5    pdf    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    5

TC1 JSON+XML - Method A - Delay 0
    [Tags]    jsonxml    methodA    delay0    email    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC2 JSON+XML - Method E - Delay 0
    [Tags]    jsonxml    methodE    delay0    email    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC3 JSON+XML - Method M - SMS only - Delay 0
    [Tags]    jsonxml    methodM    delay0    sms    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    0

TC4 JSON+XML - Method C - Email + SMS - Delay 0
    [Tags]    jsonxml    methodC    delay0    email    sms    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    0

TC5 JSON+XML - Method A - SendAsPdf - Delay 0
    [Tags]    jsonxml    methodA    delay0    pdf    schema_caveat
    [Template]    Submit Notification Scenario
    jsonxml    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    0

# =========================================================================
# 3.4  DeliveryNote - notificationDelay ΔΕΝ υπάρχει στο αρχικό template
# =========================================================================
TC1 DeliveryNote - Method A - Delay 5
    [Tags]    deliverynote    methodA    delay5    email    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC2 DeliveryNote - Method E - Delay 5
    [Tags]    deliverynote    methodE    delay5    email    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    5

TC3 DeliveryNote - Method M - SMS only - Delay 5
    [Tags]    deliverynote    methodM    delay5    sms    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    5

TC4 DeliveryNote - Method C - Email + SMS - Delay 5
    [Tags]    deliverynote    methodC    delay5    email    sms    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    5

TC5 DeliveryNote - Method A - SendAsPdf - Delay 5
    [Tags]    deliverynote    methodA    delay5    pdf    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    5

TC1 DeliveryNote - Method A - Delay 0
    [Tags]    deliverynote    methodA    delay0    email    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    A    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC2 DeliveryNote - Method E - Delay 0
    [Tags]    deliverynote    methodE    delay0    email    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    E    ${TRUE}    ${FALSE}    ${FALSE}    ${TRUE}    0

TC3 DeliveryNote - Method M - SMS only - Delay 0
    [Tags]    deliverynote    methodM    delay0    sms    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    M    ${FALSE}    ${TRUE}    ${FALSE}    ${FALSE}    0

TC4 DeliveryNote - Method C - Email + SMS - Delay 0
    [Tags]    deliverynote    methodC    delay0    email    sms    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    C    ${TRUE}    ${TRUE}    ${FALSE}    ${TRUE}    0

TC5 DeliveryNote - Method A - SendAsPdf - Delay 0
    [Tags]    deliverynote    methodA    delay0    pdf    schema_caveat
    [Template]    Submit Notification Scenario
    deliverynote    A    ${TRUE}    ${FALSE}    ${TRUE}    ${TRUE}    0

# =========================================================================
# 3.5  GRCORE - flat positional format, ΜΕΡΙΚΗ κάλυψη (4/10)
# =========================================================================
GRCORE - TransmissionMethod A
    [Tags]    grcore    methodA    partial
    [Template]    Submit Grcore Scenario
    A

GRCORE - TransmissionMethod E
    [Tags]    grcore    methodE    partial
    [Template]    Submit Grcore Scenario
    E

GRCORE - TransmissionMethod M
    [Tags]    grcore    methodM    partial
    [Template]    Submit Grcore Scenario
    M

GRCORE - TransmissionMethod C
    [Tags]    grcore    methodC    partial
    [Template]    Submit Grcore Scenario
    C

# =========================================================================
# 3.6  Cancel DeliveryNote - μόνο notificationEmails, ΜΕΡΙΚΗ κάλυψη
#      Απαιτεί mark από προηγούμενο DeliveryNote (γι' αυτό τρέχει τελευταίο).
# =========================================================================
Cancel DeliveryNote - Valid And Invalid Emails
    [Tags]    cancel    partial
    Cancel Delivery Note With Emails    ${TRUE}

Cancel DeliveryNote - Emails NULL
    [Tags]    cancel    partial
    Cancel Delivery Note With Emails    ${FALSE}


*** Keywords ***
Initialise Notification Suite
    [Documentation]    Δημιουργεί το HTTP session και ρυθμίζει τα δεδομένα payload.
    Should Not Be Equal    ${API_KEY}    ${EMPTY}
    ...    msg=Το API_KEY είναι κενό. Τρέξε με -v API_KEY:<key> ή όρισε το environment variable.
    Should Not Contain    ${UAT_API}    CHANGE-ME
    ...    msg=Το UAT_API δεν έχει οριστεί. Τρέξε με -v UAT_API:<base url>.
    ${headers}=    Create Dictionary    APIKey=${API_KEY}    Content-Type=application/json
    Create Session    ${SESSION}    ${UAT_API}    headers=${headers}    verify=${TRUE}
    Configure Payload Data
    ...    issuer_tin=${ISSUER_TIN}
    ...    counterparty_tin=${COUNTERPARTY_TIN}
    ...    valid_email=${VALID_EMAIL}
    ...    invalid_email=${INVALID_EMAIL}
    ...    valid_cell=${VALID_CELL}
    ...    invalid_cell=${INVALID_CELL}
    ...    invoice_number_seed=${INVOICE_SEED}

Submit Notification Scenario
    [Documentation]    Στέλνει ένα JSON παραστατικό με τη δοσμένη ρύθμιση ειδοποιήσεων
    ...    και επαληθεύει ΤΗΝ ΥΠΟΒΟΛΗ (όχι την παράδοση email/SMS).
    [Arguments]    ${endpoint}    ${method}    ${acct_emails}    ${cells}
    ...    ${send_pdf}    ${pdf_emails}    ${delay}

    ${caveats}=    Get Schema Caveats    ${endpoint}
    Run Keyword If    ${caveats}
    ...    Log    ΠΡΟΣΟΧΗ - πεδία εκτός αρχικού schema: ${caveats}    level=WARN

    ${body}=    Build Notification Payload
    ...    endpoint=${endpoint}
    ...    method=${method}
    ...    accounting_emails=${acct_emails}
    ...    customer_cells=${cells}
    ...    send_as_pdf=${send_pdf}
    ...    pdf_emails=${pdf_emails}
    ...    notification_delay=${delay}

    ${expected}=    Describe Expected Notification
    ...    ${method}    ${acct_emails}    ${cells}    ${send_pdf}    ${pdf_emails}
    Log    ΑΝΑΜΕΝΟΜΕΝΗ ΕΙΔΟΠΟΙΗΣΗ (χειροκίνητη επαλήθευση): ${expected}    level=INFO

    ${path}=    Get Endpoint Path    ${endpoint}
    ${resp}=    POST On Session    ${SESSION}    ${path}    json=${body}    expected_status=any

    Verify Submission Accepted    ${resp}    ${endpoint}

Submit Grcore Scenario
    [Documentation]    Στέλνει GRCORE flat αρχείο. Μόνο το TransmissionMethod μεταβάλλεται.
    [Arguments]    ${method}
    Log    GRCORE: θέσεις για cells/sendAsPdf/pdfEmails/delay άγνωστες - δεν δοκιμάζονται.
    ...    level=WARN
    ${body}=    Build Notification Payload    endpoint=grcore    method=${method}
    ${path}=    Get Endpoint Path    grcore
    ${headers}=    Create Dictionary    APIKey=${API_KEY}    Content-Type=text/plain
    ${resp}=    POST On Session    ${SESSION}    ${path}
    ...    data=${body}    headers=${headers}    expected_status=any
    Verify Submission Accepted    ${resp}    grcore

Cancel Delivery Note With Emails
    [Documentation]    Ακυρώνει το τελευταίο DeliveryNote. Απαιτεί mark από προηγούμενο test.
    [Arguments]    ${with_emails}
    Skip If    '${LAST_MARK}' == '${EMPTY}'
    ...    msg=Δεν υπάρχει διαθέσιμο mark. Τρέξε πρώτα τα DeliveryNote tests (--include deliverynote).
    Set Document Mark    ${LAST_MARK}
    ${body}=    Build Notification Payload
    ...    endpoint=cancel_dn    accounting_emails=${with_emails}
    ${path}=    Get Endpoint Path    cancel_dn
    ${resp}=    POST On Session    ${SESSION}    ${path}    json=${body}    expected_status=any
    Should Be True    ${resp.status_code} < 400
    ...    msg=Η ακύρωση απέτυχε: HTTP ${resp.status_code} - ${resp.text}

Verify Submission Accepted
    [Documentation]    Ελέγχει ότι το παραστατικό έγινε δεκτό και επιστράφηκαν mark/uid/url.
    ...    ΔΕΝ ελέγχει παράδοση ειδοποίησης - αυτό είναι ασύγχρονο.
    [Arguments]    ${resp}    ${endpoint}
    Should Be True    ${resp.status_code} < 400
    ...    msg=[${endpoint}] Απορρίφθηκε: HTTP ${resp.status_code} - ${resp.text}

    ${is_json}=    Run Keyword And Return Status    Set Variable    ${resp.json()}
    Run Keyword If    not ${is_json}
    ...    Fail    [${endpoint}] Η απάντηση δεν είναι JSON: ${resp.text}

    ${data}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${data}    mark
    ...    msg=[${endpoint}] Λείπει το 'mark' από την απάντηση: ${data}
    Dictionary Should Contain Key    ${data}    uid
    ...    msg=[${endpoint}] Λείπει το 'uid' από την απάντηση: ${data}

    ${mark}=    Get From Dictionary    ${data}    mark
    # Το 'mark' επιστρέφεται ως αριθμός στο JSON - μετατροπή σε string πριν το Should Not Be Empty.
    ${mark}=    Convert To String    ${mark}
    Should Not Be Empty    ${mark}    msg=[${endpoint}] Το 'mark' είναι κενό.
    Run Keyword If    '${endpoint}' == 'deliverynote'
    ...    Set Suite Variable    ${LAST_MARK}    ${mark}

    ${url}=    Get From Dictionary    ${data}    url    default=${EMPTY}
    Log    ΥΠΟΒΛΗΘΗΚΕ [${endpoint}] mark=${mark} url=${url}    level=INFO
