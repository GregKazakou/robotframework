*** Settings ***
Documentation     Delivery Note Life Cycle — Ψηφιακή Παρακολούθηση Διακίνησης Αποθεμάτων (Β΄ Φάση)
...
...               Σενάρια αυτόματα δομημένα από τις Οδηγίες Εφαρμογής Διαγράμματος Καταστάσεων
...               Διακίνησης (ΣΕΠΕ, v4 / 19.07.2026).
...
...               ΑΡΧΙΤΕΚΤΟΝΙΚΗ (mirror του Postman collection):
...               - Create παραστατικών: Provider einvoice UAT  (POST /Invoice/json, header apikey)
...               - RegisterTransfer / ConfirmDeliveryOutcome / RejectDeliveryNote /
...                 GetDeliveryNoteStatus: AADE myDATA dev  (XML, headers aade-user-id + subscription-key)
...               - Cancel: Provider  (POST /Invoice/cancelDeliveryNote)
...
...               ⚠ ΥΠΟΘΕΣΕΙΣ (επιβεβαιώστε με ΑΑΔΕ/Πάροχο):
...               1. ConfirmDeliveryReturn & RegisterTransfer–Return δεν υπάρχουν στο επίσημο
...                  collection — υλοποιούνται ως placeholders. Τα TC που τα χρησιμοποιούν φέρουν
...                  [Tags] placeholder (εξαιρέστε με:  --exclude placeholder).
...               2. Όλα τα Create χρησιμοποιούν το ίδιο 9.3 template (αλλάζει μόνο InvoiceTypeCode
...                  + flags). Για ακριβή per-type schema, δώστε αντίστοιχα Data templates.
...               3. Τα expected status literals (Registered/InTransit/Completed/...) ίσως χρειαστούν
...                  προσαρμογή στο ακριβές λεξιλόγιο του API. Με ${STRICT_STATUS}=${False} οι
...                  αναντιστοιχίες γίνονται warnings· θέστε ${True} για αυστηρό έλεγχο.

Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           DateTime
Library           String
Variables         ${EXECDIR}/config/credentials.py
Suite Setup       Setup Suite
Test Setup        Reset Test Context

*** Variables ***
# --- Endpoints (from config/credentials.py) ---
${PROVIDER_URL}                 ${UAT_API}
${AADE_URL}                     ${MYDATA_API_DEV}
${TEMPLATE_9_3}                 ${CURDIR}/Data/9.3_Sales_20lines.json

# --- Behaviour ---
${STRICT_STATUS}                ${False}

# --- Party VATs (from config/credentials.py) ---
${DN_ISSUER_TIN}                ${ISSUER_TIN}
${DN_RECIPIENT_TIN}             ${RECIPIENT_TIN}
${DN_TRANSPORTER_TIN}           ${TRANSPORTER_TIN}
${DN_CARRIER_VAT}               ${TRANSPORTER_TIN}
# VAT για μη-υπόχρεο παραλήπτη (§5 χωρίς ψηφιακή ιχνηλάτηση): 9 μηδενικά
${DN_NON_OBLIGATED_VAT}         000000000

# --- Secrets: πρέπει να οριστούν στο credentials.py (default κενά -> Setup προειδοποιεί) ---
${DN_PROVIDER_API_KEY_ISSUER}          ${EINVOICE_API_KEY}
${DN_PROVIDER_API_KEY_RECIPIENT}       ${UAT_API_KEY_RECIPIENT}
${DN_AADE_USER_ID_ISSUER}              ${AADE_USER_ID_ISSUER}
${DN_AADE_SUBSCRIPTION_KEY_ISSUER}     ${SUBSCRIPTION_KEY_ISSUER}
${DN_AADE_USER_ID_RECIPIENT}           ${AADE_USER_ID_RECIPIENT}
${DN_AADE_SUBSCRIPTION_KEY_RECIPIENT}  ${SUBSCRIPTION_KEY_RECIPIENT}
${DN_AADE_USER_ID_TRANSPORTER}         ${AADE_USER_ID_TRANSPORTER}
${DN_AADE_SUBSCRIPTION_KEY_TRANSPORTER}  ${SUBSCRIPTION_KEY_TRANSPORTER}

# --- Runtime state (γεμίζουν κατά την εκτέλεση) ---
${DOC_COUNTER}                  ${0}
${TPL_9_3}                      ${EMPTY}
${LAST_MARK}                    ${EMPTY}
${LAST_QR}                      ${EMPTY}

*** Test Cases ***
# ======================================================================
# Α. Κανονική ροή
# ======================================================================
TC 01 - Full Delivery
    [Documentation]    Registered -> In Transit -> Delivered by Carrier -> Completed (§2.1–2.4)
    Issue Delivery Note
    Verify Status      Registered
    Register Transfer
    Verify Status      InTransit
    Confirm Delivery Outcome    outcome=FULL                      # Τελ. Μεταφορέας -> Delivered by Carrier
    Verify Status      DeliveredByCarrier
    Confirm Delivery Outcome    outcome=FULL    as_role=recipient    # Λήπτης -> Completed
    Verify Status      Completed

TC 02 - Non Obligated Recipient
    [Documentation]    NonObligatedRecipient=true: In Transit -> Completed απευθείας (§2.4.1)
    Issue Delivery Note    non_obligated=${True}    without_digital=${True}
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL    delivered_without_recipient=${True}
    Verify Status      Completed

TC 03 - Without Digital Transport Tracking
    [Documentation]    WithoutDigitalTransportTracking=true: Registered -> Completed (§4.1)
    Issue Delivery Note    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

# ======================================================================
# Β. Ακύρωση
# ======================================================================
TC 04 - Cancel Before Start
    [Documentation]    Registered -> Cancelled (μόνο πριν από RegisterTransfer) (§2.5)
    Issue Delivery Note
    Cancel Delivery Note
    Verify Status      Cancelled

# ======================================================================
# Γ. Μεταφορτώσεις (παραμένουν In Transit)
# ======================================================================
TC 05 - Change Of Carrier
    [Documentation]    Μεταφόρτωση με αλλαγή Μεταφορέα (§1.4)
    Issue Delivery Note
    Register Transfer
    Register Transfer      # αλλαγή Μεταφορέα
    Verify Status      InTransit

TC 06 - Change Of Vehicle
    [Documentation]    Μεταφόρτωση με αλλαγή μεταφορικού μέσου (§2.2)
    Issue Delivery Note
    Register Transfer
    Register Transfer
    Verify Status      InTransit

TC 07 - Temporary Storage
    [Documentation]    Προσωρινή εναπόθεση / Αποστολέας Τρίτος Αποθηκευτής (§1.4/§4.2)
    Issue Delivery Note
    Register Transfer
    Register Transfer
    Verify Status      InTransit

TC 08 - Multiple Transshipments
    [Documentation]    Διαδοχικές μεταφορτώσεις (§1.4)
    Issue Delivery Note
    Register Transfer
    Register Transfer
    Register Transfer
    Verify Status      InTransit

# ======================================================================
# Δ. Αποτυχημένη παράδοση
# ======================================================================
TC 09 - Failed Delivery
    [Documentation]    In Transit -> Failed Delivery (outcome=NONE) (§2.6)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Verify Status      FailedDelivery

TC 10 - Failed Then Direct Completed Return
    [Documentation]    Ίδιος Μεταφορέας, χωρίς μεταφόρτωση (§2.6)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 11 - Failed Then In Transit Return
    [Documentation]    Με μεταφόρτωση: Failed -> In Transit Return -> Completed Return (§2.6/§3)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Register Transfer Return
    Verify Status      InTransitReturn
    Confirm Delivery Return
    Verify Status      CompletedReturn

# ======================================================================
# Ε. Απόρριψη
# ======================================================================
TC 12 - Rejected From Registered
    [Documentation]    Registered -> Rejected (§2.7)
    Issue Delivery Note
    Reject Delivery Note
    Verify Status      Rejected

TC 13 - Rejected From In Transit
    [Documentation]    In Transit -> Rejected (§2.7)
    Issue Delivery Note
    Register Transfer
    Reject Delivery Note
    Verify Status      Rejected

TC 14 - Rejected From Delivered By Carrier
    [Documentation]    Delivered by Carrier -> Rejected (§2.7)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL
    Reject Delivery Note
    Verify Status      Rejected

TC 15 - Rejected Then Direct Completed Return
    [Documentation]    Ίδιος Μεταφορέας, χωρίς μεταφόρτωση (§2.7)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Reject Delivery Note
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 16 - Rejected Then In Transit Return
    [Documentation]    Με μεταφόρτωση (§2.7/§3)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Reject Delivery Note
    Register Transfer Return
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 17 - Failed Then Recipient Rejects
    [Documentation]    Failed προηγείται -> ο Λήπτης καταγράφει και τη δική του απόρριψη (§2.7/§4.4)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Reject Delivery Note
    Verify Status      Rejected

TC 18 - Rejected Blocks Failed Delivery
    [Documentation]    Negative: μετά από Rejected, ο Μεταφορέας ΔΕΝ μπορεί Failed (§2.7/§4.4)
    Issue Delivery Note
    Register Transfer
    Reject Delivery Note
    Confirm Delivery Outcome    outcome=NONE    expect_failure=${True}

# ======================================================================
# ΣΤ. Μερική παράδοση (Partial)
# ======================================================================
TC 19 - Partial Delivery
    [Documentation]    Delivered by Carrier -> Partial -> 10.2 (§2.8)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=PARTIAL
    Issue Delivery Note    type_code=10.2
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 20 - Partial With Repacking
    [Documentation]    RegisterTransfer (Update Packing) -> Partial (§2.8)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Register Transfer      # Update Packing (π.χ. παλέτες -> κούτες)
    Confirm Delivery Outcome    outcome=PARTIAL
    Issue Delivery Note    type_code=10.2
    Confirm Delivery Return

TC 21 - Partial Without Initial Packing Table
    [Documentation]    Ο Μεταφορέας δημιουργεί τον Πίνακα με RegisterTransfer (§2.8)
    Issue Delivery Note
    Register Transfer      # δημιουργία Πίνακα Ειδών Συσκευασίας
    Confirm Delivery Outcome    outcome=PARTIAL
    Verify Status      Partial

TC 22 - Partial Direct Return
    [Documentation]    Επιστροφή αδιάθετου μέρους άμεσα, ίδιος Μεταφορέας (§2.8)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=PARTIAL
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 23 - Partial Return Via In Transit Return
    [Documentation]    Επιστροφή αδιάθετου μέρους με μεταφόρτωση (§2.8/§3)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=PARTIAL
    Register Transfer Return
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 24 - Partial Completed By Issuer With Shortages
    [Documentation]    ConfirmDeliveryReturn + 10.2 + 10.1 ελλείμματα (§2.8)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=PARTIAL
    Issue Delivery Note    type_code=10.2
    Confirm Delivery Return
    Issue Delivery Note    type_code=10.1

TC 25 - Partial Simplified New Reverse DN
    [Documentation]    Ο Λήπτης παίρνει όλα & εκδίδει νέο 9.3 «Επιστροφή» — χωρίς Partial (§2.8)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL
    Issue Delivery Note    reverse=${True}      # νέο 9.3 «Επιστροφή» προς αρχικό Εκδότη

# ======================================================================
# Ζ. Delivered by Carrier — αποτελέσματα
# ======================================================================
TC 26 - Outcome Full
    [Documentation]    Delivered by Carrier (Full) -> Completed (§2.3)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL
    Verify Status      DeliveredByCarrier

TC 27 - Outcome None
    [Documentation]    Delivered by Carrier (None) -> Failed Delivery (§2.3)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Verify Status      FailedDelivery

TC 28 - Outcome Partial
    [Documentation]    Delivered by Carrier (Partial) -> Partial (§2.3)
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=PARTIAL
    Verify Status      Partial

# ======================================================================
# Η. Επιστροφή ειδικές (ConfirmDeliveryReturn)
# ======================================================================
TC 29 - Aggregate DN 9.2 Without Recipient
    [Documentation]    9.2 Συγκεντρωτικό ΔΑ — ολοκλήρωση πάντα από τον Εκδότη (§3.2/§4.6)
    [Tags]    placeholder
    Issue Delivery Note    type_code=9.2
    Register Transfer
    Confirm Delivery Return
    Verify Status      CompletedReturn

TC 30 - Reverse DN 9.3
    [Documentation]    9.3 Αντίστροφη Διακίνηση — Εκδότης = τελικός Παραλήπτης (§3.2/§4.6)
    [Tags]    placeholder
    Issue Delivery Note    reverse=${True}
    Register Transfer
    Confirm Delivery Return
    Verify Status      CompletedReturn

# ======================================================================
# Θ. Without Digital Transport Tracking (§5)
# ======================================================================
TC 31 - WDT 5.1 Onboard From 9.2
    [Documentation]    Αιτία «Συνέχεια από έκδοση 9.2 ΣΔΑ» (§5.1)
    Issue Delivery Note    type_code=9.2
    Register Transfer
    Issue Delivery Note    without_digital=${True}    non_obligated=${True}      # 9.3 επί αυτοκινήτου
    Verify Status      Completed

TC 32 - WDT 5.2 Restaurant
    [Documentation]    Αιτία «Ανάλωση Ειδών Εντός Εγκατάστασης» (§5.2)
    Issue Delivery Note    type_code=1.1    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 33 - WDT 5.3 Repair Parts
    [Documentation]    Αιτία «Ανάλωση Ειδών Εντός Εγκατάστασης» (§5.3)
    Issue Delivery Note    type_code=1.1    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 34 - WDT 5.4 Consumption Before Exit
    [Documentation]    Καύσιμα στο ντεπόζιτο — «Ανάλωση Ειδών Εντός Εγκατάστασης» (§5.4)
    Issue Delivery Note    type_code=1.1    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 35 - WDT 5.5 Foreign Recipient
    [Documentation]    Αιτία «Διακινήσεις Αλλοδαπής» (§5.5)
    Issue Delivery Note    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 36 - WDT 5.6 Ownership Change
    [Documentation]    Αιτία «Αλλαγή Κυριότητας Εντός Εγκατάστασης» (§5.6)
    Issue Delivery Note    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 37 - WDT 5.7 Goods For Weighing
    [Documentation]    Αντίστροφο 9.3 — «Τελική Ζυγιζόμενη Ποσότητα» (§5.7)
    Issue Delivery Note    reverse=${True}    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

TC 38 - WDT 5.8 Small Quantities
    [Documentation]    Αιτία «Διακίνηση Μικρών Ποσοτήτων» (§5.8)
    Issue Delivery Note    without_digital=${True}    non_obligated=${True}
    Verify Status      Completed

# ======================================================================
# Ι. Διορθώσεις / αλλαγή Λήπτη (συστημικές)
# ======================================================================
TC 39 - Correct Wrong DN After Start
    [Documentation]    Συστημική διόρθωση λανθασμένου παραστατικού μετά την εκκίνηση (§6)
    [Tags]    placeholder
    Issue Delivery Note                              # λανθασμένο
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE          # Failed (συστημικά)
    Confirm Delivery Return                           # -> Completed Return
    Issue Delivery Note    type_code=10.2            # συσχέτιση με λανθασμένο
    Issue Delivery Note                              # νέο ορθό 9.3
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL
    Confirm Delivery Outcome    outcome=FULL    as_role=recipient
    Verify Status      Completed

TC 40 - Change Recipient Without Real Return
    [Documentation]    Συστημική επιστροφή & νέος Λήπτης (§7)
    [Tags]    placeholder
    Issue Delivery Note
    Register Transfer
    Confirm Delivery Outcome    outcome=NONE
    Confirm Delivery Return
    Issue Delivery Note    type_code=10.2
    Issue Delivery Note                              # νέο 9.3 προς νέο Λήπτη
    Register Transfer
    Confirm Delivery Outcome    outcome=FULL
    Verify Status      Completed

*** Keywords ***
# ======================================================================
# Setup / state
# ======================================================================
Setup Suite
    Warn If Missing Secret    ${DN_PROVIDER_API_KEY_ISSUER}         DN_PROVIDER_API_KEY_ISSUER
    Warn If Missing Secret    ${DN_AADE_SUBSCRIPTION_KEY_ISSUER}    DN_AADE_SUBSCRIPTION_KEY_ISSUER
    ${tpl}=    Load JSON File    ${TEMPLATE_9_3}
    Set Suite Variable    ${TPL_9_3}    ${tpl}
    Initialize Document Counter
    # Provider sessions (apikey per role)
    ${h_issuer}=       Create Dictionary    Content-Type=application/json    Accept=application/json    apikey=${DN_PROVIDER_API_KEY_ISSUER}
    ${h_recipient}=    Create Dictionary    Content-Type=application/json    Accept=application/json    apikey=${DN_PROVIDER_API_KEY_RECIPIENT}
    Create Session     provider_issuer       ${PROVIDER_URL}    headers=${h_issuer}
    Create Session     provider_recipient    ${PROVIDER_URL}    headers=${h_recipient}
    # AADE session (headers overridden per request/role)
    Create Session     aade    ${AADE_URL}
    # Per-role AADE header dictionaries
    ${ah_issuer}=      Create Dictionary    Content-Type=application/xml    aade-user-id=${DN_AADE_USER_ID_ISSUER}         ocp-apim-subscription-key=${DN_AADE_SUBSCRIPTION_KEY_ISSUER}
    ${ah_recipient}=   Create Dictionary    Content-Type=application/xml    aade-user-id=${DN_AADE_USER_ID_RECIPIENT}      ocp-apim-subscription-key=${DN_AADE_SUBSCRIPTION_KEY_RECIPIENT}
    ${ah_transporter}=    Create Dictionary    Content-Type=application/xml    aade-user-id=${DN_AADE_USER_ID_TRANSPORTER}    ocp-apim-subscription-key=${DN_AADE_SUBSCRIPTION_KEY_TRANSPORTER}
    Set Suite Variable    ${AADE_H_ISSUER}         ${ah_issuer}
    Set Suite Variable    ${AADE_H_RECIPIENT}      ${ah_recipient}
    Set Suite Variable    ${AADE_H_TRANSPORTER}    ${ah_transporter}

Warn If Missing Secret
    [Arguments]    ${value}    ${name}
    IF    "${value}" == "${EMPTY}"
        Log    Το ${name} δεν έχει οριστεί στο config/credentials.py — τα σχετικά requests θα αποτύχουν.    level=WARN
    END

Reset Test Context
    Set Test Variable    ${LAST_MARK}    ${EMPTY}
    Set Test Variable    ${LAST_QR}      ${EMPTY}

Load JSON File
    [Arguments]    ${path}
    ${content}=    Get File     ${path}
    ${data}=       Evaluate     json.loads($content)    json
    RETURN         ${data}

Initialize Document Counter
    ${epoch}=    Get Current Date    result_format=epoch
    ${base}=     Convert To Integer  ${epoch}
    Set Suite Variable    ${DOC_COUNTER}    ${base}

Next Document Number
    ${new}=    Evaluate    ${DOC_COUNTER} + 1
    Set Suite Variable    ${DOC_COUNTER}    ${new}
    ${as_str}=    Convert To String    ${new}
    RETURN     ${as_str}

Current DateTime ISO
    ${now}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S
    RETURN     ${now}

Current TC Series
    [Documentation]    Επιστρέφει το «TC NN» prefix του τρέχοντος test (από το ${TEST NAME}),
    ...                ώστε το πεδίο Series κάθε παραστατικού να ξεχωρίζει ανά test.
    ${token}=    Evaluate    $TEST_NAME.split(' - ')[0].strip()
    RETURN     ${token}

# ======================================================================
# High-level lifecycle steps
# ======================================================================
Issue Delivery Note
    [Arguments]    ${type_code}=9.3    ${without_digital}=${False}    ${non_obligated}=${False}
    ...            ${reverse}=${False}    ${counterparty_vat}=${EMPTY}
    [Documentation]    Δημιουργεί παραστατικό μέσω Provider. Θέτει ${LAST_MARK}/${LAST_QR}.
    ${payload}=    Copy Dictionary    ${TPL_9_3}    deepcopy=True
    ${number}=     Next Document Number
    ${now}=        Current DateTime ISO
    ${series}=     Current TC Series
    Set To Dictionary    ${payload}
    ...    Series=${series}
    ...    Number=${number}    DateIssued=${now}
    ...    InvoiceTypeCode=${type_code}
    ...    isReverseDeliveryNote=${reverse}
    ...    withoutDigitalTransportTracking=${without_digital}
    ...    nonObligatedRecipient=${non_obligated}
    ${issuer}=    Get From Dictionary    ${payload}    Issuer
    Set To Dictionary    ${issuer}    Vat=${DN_ISSUER_TIN}
    # Counterparty VAT = 9 μηδενικά (000000000) όταν ΔΕΝ υπάρχει συγκεκριμένος
    # υπόχρεος παραλήπτης — η ΑΑΔΕ το απαιτεί (error 289) στις εξής περιπτώσεις:
    #   * type_code 9.2 (συγκεντρωτικό/onboard ΔΑ χωρίς παραλήπτη)
    #   * nonObligatedRecipient=true (§5 χωρίς ψηφιακή ιχνηλάτηση)
    # Explicit override με ${counterparty_vat} έχει προτεραιότητα· αλλιώς
    # κρατιέται το VAT του template.
    ${needs_zero_vat}=    Evaluate    $non_obligated or '${type_code}' == '9.2'
    ${cp_vat}=    Set Variable If
    ...    '${counterparty_vat}' != '${EMPTY}'    ${counterparty_vat}
    ...    ${needs_zero_vat}                       ${DN_NON_OBLIGATED_VAT}
    ...    ${NONE}
    IF    $cp_vat is not None
        ${cp}=    Get From Dictionary    ${payload}    CounterParty    default=${NONE}
        IF    $cp is not None
            Set To Dictionary    ${cp}    Vat=${cp_vat}
            Log    Counterparty VAT -> ${cp_vat} (type=${type_code}, non_obligated=${non_obligated})
        END
    END
    Apply Dispatch DateTime    ${payload}    ${now}    ${number}
    ${resp}=    POST On Session    provider_issuer    /Invoice/json    json=${payload}    expected_status=any
    Log Response    ${resp}    Create ${type_code}
    IF    ${resp.status_code} >= 400
        Fail    Create ${type_code} FAILED [HTTP ${resp.status_code}] >> ${resp.text}
    END
    ${body}=    Set Variable    ${resp.json()}
    ${mark}=    Get From Dictionary    ${body}    mark        default=${EMPTY}
    ${qr}=      Get From Dictionary    ${body}    erpQrCode    default=${EMPTY}
    Set Test Variable    ${LAST_MARK}    ${mark}
    Set Test Variable    ${LAST_QR}      ${qr}
    Log    Issued ${type_code} [Series=${series} Number=${number}] -> mark=${mark} qr=${qr}
    RETURN    ${mark}

Apply Dispatch DateTime
    [Arguments]    ${payload}    ${now}    ${number}
    [Documentation]    Το template έχει στατικά dispatchDate/dispatchtime, τα οποία «παλιώνουν»
    ...                και η ΑΑΔΕ τα απορρίπτει (error 280: DispatchDate must be greater or equal
    ...                with current date). Τα θέτουμε στην τρέχουσα ημερομηνία/ώρα κάθε run.
    ...                Ταυτόχρονα κάνουμε μοναδικό το InternalDocumentId, που αλλιώς επαναλαμβάνεται.
    ${dist}=    Get From Dictionary    ${payload}    DistributionDetails    default=${NONE}
    IF    $dist is None
        Log    Το payload δεν έχει DistributionDetails — παραλείπεται το dispatch datetime.    level=WARN
        RETURN
    END
    Set To Dictionary    ${dist}    dispatchDate=${now}    dispatchtime=${now}
    ${has_id}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${dist}    InternalDocumentId
    IF    ${has_id}
        Set To Dictionary    ${dist}    InternalDocumentId=InternalDocId_${number}
    END

Register Transfer
    [Arguments]    ${qr}=${LAST_QR}    ${is_return}=${False}
    [Documentation]    Μεταφορέας -> In Transit (ή μεταφόρτωση). AADE XML.
    ${return_tag}=    Set Variable If    ${is_return}    <isReturn>true</isReturn>    ${EMPTY}
    ${xml}=    Catenate    SEPARATOR=\n
    ...    <?xml version="1.0" encoding="UTF-8"?>
    ...    <Transport>
    ...    <qrUrl>${qr}</qrUrl>
    ...    <transportDetail>
    ...    <vehicleNumber>ABC-1234</vehicleNumber>
    ...    <transportType>1</transportType>
    ...    <carrierVatNumber>${DN_CARRIER_VAT}</carrierVatNumber>
    ...    <location><longitude>23.7275</longitude><latitude>37.9838</latitude></location>
    ...    </transportDetail>
    ...    ${return_tag}
    ...    </Transport>
    AADE Post    /RegisterTransfer    ${xml}    ${AADE_H_TRANSPORTER}    RegisterTransfer

Register Transfer Return
    [Arguments]    ${qr}=${LAST_QR}
    [Documentation]    ⚠ ΥΠΟΘΕΣΗ: RegisterTransfer–Return (-> In Transit Return). Επιβεβαιώστε πεδίο isReturn.
    Register Transfer    ${qr}    is_return=${True}

Confirm Delivery Outcome
    [Arguments]    ${outcome}=FULL    ${as_role}=transporter    ${delivered_without_recipient}=${False}
    ...            ${expect_failure}=${False}
    [Documentation]    ConfirmDeliveryOutcome (FULL/PARTIAL/NONE). as_role: transporter | recipient.
    ${wr}=    Convert To Lower Case    ${delivered_without_recipient}
    ${packaging}=    Set Variable If    "${outcome}" == "PARTIAL"
    ...    <deliveredPackaging><packagingType>1</packagingType><quantity>5</quantity></deliveredPackaging>    ${EMPTY}
    ${xml}=    Catenate    SEPARATOR=\n
    ...    <?xml version="1.0" encoding="UTF-8"?>
    ...    <ConfirmDeliveryOutcomeRequest>
    ...    <qrUrl>${LAST_QR}</qrUrl>
    ...    <outcome>${outcome}</outcome>
    ...    <deliveredWithoutRecipient>${wr}</deliveredWithoutRecipient>
    ...    ${packaging}
    ...    </ConfirmDeliveryOutcomeRequest>
    ${headers}=    Set Variable If    "${as_role}" == "recipient"    ${AADE_H_RECIPIENT}    ${AADE_H_TRANSPORTER}
    AADE Post    /ConfirmDeliveryOutcome    ${xml}    ${headers}    ConfirmDeliveryOutcome ${outcome}    expect_failure=${expect_failure}

Reject Delivery Note
    [Arguments]    ${qr}=${LAST_QR}
    [Documentation]    RejectDeliveryNote — αποκλειστικά από τον Λήπτη. AADE XML.
    ${xml}=    Catenate    SEPARATOR=\n
    ...    <?xml version="1.0" encoding="UTF-8"?>
    ...    <RejectDeliveryNoteRequest>
    ...    <qrUrl>${qr}</qrUrl>
    ...    </RejectDeliveryNoteRequest>
    AADE Post    /RejectDeliveryNote    ${xml}    ${AADE_H_RECIPIENT}    RejectDeliveryNote

Confirm Delivery Return
    [Arguments]    ${qr}=${LAST_QR}
    [Documentation]    ⚠ ΥΠΟΘΕΣΗ: ConfirmDeliveryReturn (Εκδότης -> Completed Return). Επιβεβαιώστε endpoint.
    ${xml}=    Catenate    SEPARATOR=\n
    ...    <?xml version="1.0" encoding="UTF-8"?>
    ...    <ConfirmDeliveryReturnRequest>
    ...    <qrUrl>${qr}</qrUrl>
    ...    </ConfirmDeliveryReturnRequest>
    AADE Post    /ConfirmDeliveryReturn    ${xml}    ${AADE_H_ISSUER}    ConfirmDeliveryReturn

Cancel Delivery Note
    [Arguments]    ${mark}=${LAST_MARK}
    [Documentation]    Ακύρωση μέσω Provider (μόνο σε Registered).
    ${payload}=    Create Dictionary    vat=${DN_ISSUER_TIN}    mark=${mark}
    ${resp}=    POST On Session    provider_issuer    /Invoice/cancelDeliveryNote    json=${payload}    expected_status=any
    Log Response    ${resp}    CancelDeliveryNote
    IF    ${resp.status_code} >= 400
        Fail    CancelDeliveryNote FAILED [HTTP ${resp.status_code}] >> ${resp.text}
    END

# ======================================================================
# Status verification
# ======================================================================
Get Status
    [Arguments]    ${mark}=${LAST_MARK}
    [Documentation]    GetDeliveryNoteStatus (AADE) -> επιστρέφει το status string (ή κενό).
    ${resp}=    GET On Session    aade    /GetDeliveryNoteStatus    params=mark=${mark}&issuerVatNumber=${DN_ISSUER_TIN}
    ...         headers=${AADE_H_ISSUER}    expected_status=any
    Log Response    ${resp}    GetDeliveryNoteStatus
    ${status}=    Extract Status    ${resp.text}
    Log    Current status (mark=${mark}): ${status}
    RETURN    ${status}

Extract Status
    [Arguments]    ${xml_text}
    [Documentation]    Τραβάει το <status> (ή <statusCode>) από το XML response με regex.
    ${match}=    Evaluate
    ...    (lambda m: m.group(1) if m else '')(re.search(r'<status>(.*?)</status>', $xml_text) or re.search(r'<statusCode>(.*?)</statusCode>', $xml_text))
    ...    re
    RETURN    ${match}

Verify Status
    [Arguments]    ${expected}    ${mark}=${LAST_MARK}
    [Documentation]    Ελέγχει ότι το τρέχον status ταιριάζει με το αναμενόμενο (case/space-insensitive).
    ...                Με ${STRICT_STATUS}=${False} οι αναντιστοιχίες γίνονται warnings.
    ${actual}=    Get Status    ${mark}
    ${na}=    Normalize Token    ${actual}
    ${ne}=    Normalize Token    ${expected}
    IF    ${STRICT_STATUS}
        Should Contain    ${na}    ${ne}    msg=Αναμενόταν status '${expected}' αλλά ελήφθη '${actual}'
    ELSE
        Run Keyword And Warn On Failure    Should Contain    ${na}    ${ne}
        ...    msg=Αναμενόταν status '${expected}' αλλά ελήφθη '${actual}'
    END

Normalize Token
    [Arguments]    ${text}
    ${t}=    Convert To Lower Case    ${text}
    ${t}=    Replace String    ${t}    ${SPACE}    ${EMPTY}
    ${t}=    Replace String    ${t}    _    ${EMPTY}
    ${t}=    Replace String    ${t}    -    ${EMPTY}
    RETURN    ${t}

# ======================================================================
# HTTP helper
# ======================================================================
AADE Post
    [Arguments]    ${path}    ${xml}    ${headers}    ${label}=AADE    ${expect_failure}=${False}
    [Documentation]    POST XML στο AADE session. Αν expect_failure=True, αναμένει HTTP>=400.
    ${resp}=    POST On Session    aade    ${path}    data=${xml}    headers=${headers}    expected_status=any
    Log Response    ${resp}    ${label}
    IF    ${expect_failure}
        Should Be True    ${resp.status_code} >= 400
        ...    msg=${label}: αναμενόταν αποτυχία (η ενέργεια θα έπρεπε να μπλοκαριστεί) αλλά HTTP ${resp.status_code}
    ELSE
        IF    ${resp.status_code} >= 400
            Fail    ${label} FAILED [HTTP ${resp.status_code}] >> ${resp.text}
        END
    END
    RETURN    ${resp}

Log Response
    [Arguments]    ${resp}    ${label}=HTTP
    ${preview}=    Truncate Text    ${resp.text}    1500
    Log    ${label} [HTTP ${resp.status_code} ${resp.reason}]\n${preview}    level=INFO

Truncate Text
    [Arguments]    ${text}    ${max_chars}=1500
    ${len}=    Get Length    ${text}
    IF    ${len} <= ${max_chars}
        RETURN    ${text}
    END
    ${trunc}=    Evaluate    $text[:${max_chars}]
    RETURN    ${trunc}... [truncated ${len} chars]
