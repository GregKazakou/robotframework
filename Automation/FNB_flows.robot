*** Test Cases ***
TC 01 - Simple Close
    [Documentation]    8.6 debit 50 -> 11.1 debit 50
    Send 8.6 Debit     gross=50
    Send 11.1 Debit    gross=50    expected_marks_count=1

TC 02 - Order With Return Before Payment    #check clearance
    [Documentation]    8.6 debit 100 -> 8.6 credit 20 -> 11.1 debit 80
    Send 8.6 Debit     gross=100
    Send 8.6 Credit    gross=20
    Send 11.1 Debit    gross=80    expected_marks_count=2

TC 03 - Multiple Orders One Close
    Send 8.6 Debit     gross=25
    Send 8.6 Debit     gross=35
    Send 8.6 Debit     gross=15
    Send 11.1 Debit    gross=75    expected_marks_count=3

TC 04 - Two Rounds Same Table
    Send 8.6 Debit     gross=40
    Send 11.1 Debit    gross=40    expected_marks_count=1
    Send 8.6 Debit     gross=30
    Send 11.1 Debit    gross=30    expected_marks_count=1

TC 05 - Full Cancellation By Credit And New Order    #check clearance
    [Documentation]    Πλήρης επιστροφή με 8.6 credit (όχι cancel) και νέα παραγγελία
    Send 8.6 Debit     gross=60
    Send 8.6 Credit    gross=60
    Send 8.6 Debit     gross=45
    Send 11.1 Debit    gross=45    expected_marks_count=3

TC 06 - Return After Receipt With 11 4    #check clearance
    [Documentation]    8.6 debit 50 -> 11.1 debit 50 -> 11.4 credit 10 για επιστροφή
    Send 8.6 Debit     gross=50
    Send 11.1 Debit    gross=50    expected_marks_count=1
    Send 11.4 Credit   gross=10    expected_marks_count=0

TC 07.1 - Mixed Complex Flow 11.1 Debit
    [Documentation]    Το σύνθετο σενάριο με 9 βήματα (το τελευταίο είναι 11.4 πιστωτική)
    Send 8.6 Debit     gross=10        # M1
    Send 8.6 Debit     gross=30        # M2
    Send 8.6 Credit    gross=10        # M3
    Send 11.1 Debit    gross=20    expected_marks_count=3   peek=${True}    # connects [M1,M2,M3]
    Send 8.6 Debit     gross=30        # M4
    Send 11.1 Debit    gross=30    expected_marks_count=4   peek=${True}    # connects [M1,M2,M3,M4]
    Send 8.6 Debit     gross=20        # M5
    Send 8.6 Credit    gross=20        # M6
    Send 11.1 Debit    gross=10    expected_marks_count=6   # connects [M1,M2,M3,M4, M5,M6]

TC 07.2 - Mixed Complex Flow 11.4 Credit
    [Documentation]    Το σύνθετο σενάριο με 9 βήματα (το τελευταίο είναι 11.4 πιστωτική)
    Send 8.6 Debit     gross=10        # M1
    Send 8.6 Debit     gross=30        # M2
    Send 8.6 Credit    gross=10        # M3
    Send 11.1 Debit    gross=20    expected_marks_count=3   peek=${True}    # connects [M1,M2,M3]
    Send 8.6 Debit     gross=30        # M4
    Send 11.1 Debit    gross=30    expected_marks_count=4   peek=${True}    # connects [M1,M2,M3,M4]
    Send 8.6 Debit     gross=20        # M5
    Send 8.6 Credit    gross=40        # M6
    Send 11.4 Credit    gross=10    expected_marks_count=6   # connects [M1,M2,M3,M4, M5,M6]
#TC 07.3 - Mixed Complex Flow 11.1 Debit
#    [Documentation]    Το σύνθετο σενάριο με 9 βήματα (το τελευταίο είναι 11.1)
#    Send 8.6 Debit     gross=10        # M1
#    Send 8.6 Debit     gross=30        # M2
#    Send 8.6 Credit    gross=10        # M3
#    Send 11.1 Debit    gross=20    expected_marks_count=3   peek=${True}    # connects [M1,M2,M3]
#    Send 8.6 Debit     gross=30        # M4
#    Send 11.1 Debit    gross=30    expected_marks_count=2   peek=${True}    # connects [M3,M4]
#    Send 8.6 Debit     gross=20        # M5
#    Send 8.6 Credit    gross=20        # M6
#    Send 11.1 Debit    gross=10    expected_marks_count=3   # connects [M4, M5,M6]
TC 08 - Split Bill
    Send 8.6 Debit     gross=40
    Send 8.6 Debit     gross=40
    Send 11.1 Debit    gross=40    expected_marks_count=2    close_all_pending=${False}    peek=${True}
    Send 11.1 Debit    gross=40    expected_marks_count=2

TC 09 - Partial Payment Then New Order
    Send 8.6 Debit     gross=80
    Send 11.1 Debit    gross=50    expected_marks_count=1    close_all_pending=${False}    peek=${True}
    Send 8.6 Debit     gross=25
    Send 11.1 Debit    gross=55    expected_marks_count=2

TC 10 - Mixed VAT Rates
    [Documentation]    Κινήσεις με διαφορετικούς συντελεστές ΦΠΑ στο ίδιο τραπέζι
    Send 8.6 Debit     gross=100   vat_rate=${13}
    Send 8.6 Debit     gross=60    vat_rate=${24}
    Send 11.1 Debit    gross=160   expected_marks_count=2    vat_rate=${13}

TC 11 - Cancel All Before Receipt
    [Documentation]    Ο πελάτης φεύγει, ακυρώνουμε όλα τα pending 8.6 πριν εκδοθεί 11.1
    Send 8.6 Debit     gross=50
    Send 8.6 Debit     gross=30
    Send 8.6 Cancel
    Pool Should Be Empty

TC 12 - Partial Cancel Then Pay Rest
    [Documentation]    Ακυρώνουμε συγκεκριμένο 8.6 (λάθος πιάτο), τα υπόλοιπα πάνε στην απόδειξη
    ${m1}=    Send 8.6 Debit     gross=40
    ${m2}=    Send 8.6 Debit     gross=25
    ${m3}=    Send 8.6 Debit     gross=35
    Send 8.6 Cancel    ${m2}
    Send 11.1 Debit    gross=75    expected_marks_count=2

TC 13 - Cancel A Credit
    [Documentation]    Ακύρωση λανθασμένης έκπτωσης και χρέωση πλήρους ποσού
    ${m1}=    Send 8.6 Debit     gross=60
    ${m2}=    Send 8.6 Credit    gross=15
    Send 8.6 Cancel    ${m2}
    Send 11.1 Debit    gross=60    expected_marks_count=1

TC 14 - Cancel Mixed Flow
    [Documentation]    Σύνθετο: ακύρωση σε πολλαπλούς γύρους με ενδιάμεσες 11.1
    ${m1}=    Send 8.6 Debit     gross=45
    ${m2}=    Send 8.6 Debit     gross=20
    Send 8.6 Cancel    ${m2}
    Send 11.1 Debit    gross=45    expected_marks_count=1
    ${m3}=    Send 8.6 Debit     gross=30
    ${m4}=    Send 8.6 Debit     gross=25
    Send 8.6 Cancel
    Pool Should Be Empty

TC 15 - Zero Value Receipt Close
    [Documentation]    Balance του τραπεζιού = 0 (π.χ. comp meal, 8.6 debit = 8.6 credit).
    ...                Πρέπει να εκδοθεί 11.1 με gross=0 για να κλείσουν τα MARKs στον κόμβο.
    ...                Το vat_rate διατηρείται ίδιο με τα 8.6 (13%), ώστε VatCategoryCode=2.
    Send 8.6 Debit     gross=50    vat_rate=${13}
    Send 8.6 Credit    gross=50    vat_rate=${13}
    Send 11.1 Debit    gross=0     vat_rate=${13}    expected_marks_count=2
    Pool Should Be Empty

TC 16 - Zero After Multiple Offsetting Moves
    [Documentation]    Πολλαπλές κινήσεις που ακυρώνονται μεταξύ τους. Τα 8.6 είναι 13%,
    ...                άρα το μηδενικό 11.1 πρέπει επίσης να φέρει VatCategoryCode=2.
    Send 8.6 Debit     gross=30    vat_rate=${13}
    Send 8.6 Debit     gross=20    vat_rate=${13}
    Send 8.6 Credit    gross=30    vat_rate=${13}
    Send 8.6 Credit    gross=20    vat_rate=${13}
    Send 11.1 Debit    gross=0     vat_rate=${13}    expected_marks_count=4
    Pool Should Be Empty

TC 17 - Zero After Multiple Offsetting Moves
    [Documentation]    Πολλαπλές κινήσεις που ακυρώνονται μεταξύ τους. Τα 8.6 είναι 13%,
    ...                άρα το μηδενικό 11.1 πρέπει επίσης να φέρει VatCategoryCode=2.
    ${m1}=    Send 8.6 Debit     gross=50    vat_rate=${13}
    ${m2}=    Send 11.1 Debit    gross=30    vat_rate=${13}    ${m1}
    ${m3}=    Send 8.6 Credit    gross=30    vat_rate=${13}
    ${m4}=    Send 11.4 Credit    gross=30    vat_rate=${13}    
    ${m5}=    Send 8.6 Credit    gross=20    vat_rate=${13}
    ${m6}=    Send 11.1 Debit    gross=0     vat_rate=${13}
    ${m7}=    Send 11.4 Credit    gross=0     vat_rate=${13}    expected_marks_count=4
    Pool Should Be Empty

*** Settings ***
Documentation     FNB (Food & Beverage) Table Order Scenarios
...               Ροή: 8.6 debit/credit/cancel -> MARKs συσσωρεύονται ανά τραπέζι.
...               11.1 receipt κλείνει τα pending 8.6 MARKs μέσω multipleConnectedMarks.
...               11.4 receipt είναι η retail πιστωτική (ίδιο schema με 11.1, διαφορετικός InvoiceTypeCode).
...               Cancel 8.6 αφαιρεί MARKs από το pool και ΔΕΝ περιλαμβάνει ποσά (αλλά Quantity=1).

Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           DateTime
Library           String
Variables         ${EXECDIR}/config/credentials.py
Suite Setup       Setup Suite
Test Setup        Reset Pending Marks Pool

*** Variables ***
${BASE_URL}                https://einvoiceapiuat.impact.gr
${TEMPLATE_8_6}            ${CURDIR}/Data/8.6_Debit_FNB_Form.json
${TEMPLATE_8_6_CREDIT}     ${CURDIR}/Data/8.6_Return_FNB_Form.json
${TEMPLATE_8_6_CANCEL}     ${CURDIR}/Data/8.6_Cancel_FNB_Form.json
${TEMPLATE_11_1}           ${CURDIR}/Data/11.1_FNB_Retail_Sales_Receipt.json
${TABLE_ID}                20
${DEFAULT_VAT_RATE}        ${13}
${PRODUCT_CODE}            251320104
${API_KEY}                 ${EINVOICE_API_KEY}
${ISSUER_VAT}              EL154697391
${API_KEY_HEADER_NAME}     apikey
@{PENDING_MARKS}
${DOC_COUNTER}             ${0}
${TPL_8_6}                 ${EMPTY}
${TPL_8_6_CREDIT}          ${EMPTY}
${TPL_8_6_CANCEL}          ${EMPTY}
${TPL_11_1}                ${EMPTY}

*** Keywords ***
# ======================================================================
# Setup / State management
# ======================================================================

Setup Suite
    Load Base Templates
    Initialize Document Counter
    ${headers}=           Create Dictionary
    ...    Content-Type=application/json
    ...    Accept=application/json
    ...    apikey=${API_KEY}
    Create Session        fnb    ${BASE_URL}    headers=${headers}
    Log                   Session created    level=DEBUG


Load Base Templates
    ${tpl_8_6}=           Load JSON File         ${TEMPLATE_8_6}
    ${tpl_8_6_cr}=        Load JSON File         ${TEMPLATE_8_6_CREDIT}
    ${tpl_8_6_cn}=        Load JSON File         ${TEMPLATE_8_6_CANCEL}
    ${tpl_11_1}=          Load JSON File         ${TEMPLATE_11_1}
    Set Suite Variable    ${TPL_8_6}             ${tpl_8_6}
    Set Suite Variable    ${TPL_8_6_CREDIT}      ${tpl_8_6_cr}
    Set Suite Variable    ${TPL_8_6_CANCEL}      ${tpl_8_6_cn}
    Set Suite Variable    ${TPL_11_1}            ${tpl_11_1}

Load JSON File
    [Arguments]           ${path}
    [Documentation]       Διαβάζει JSON αρχείο και το επιστρέφει ως Python dict.
    ...                   Χρησιμοποιεί built-in libs, οπότε δεν χρειάζεται το JSONLibrary.
    ${content}=           Get File               ${path}
    ${data}=              Evaluate               json.loads($content)    json
    RETURN                ${data}

Initialize Document Counter
    [Documentation]    Base = epoch seconds, άρα κάθε run ξεκινά με ≠ τιμή (uniqueness μεταξύ runs)
    ${epoch}=             Get Current Date       result_format=epoch
    ${base}=              Convert To Integer     ${epoch}
    Set Suite Variable    ${DOC_COUNTER}         ${base}

Next Document Number
    [Documentation]    Επιστρέφει μοναδικό string για κάθε document
    ${new}=               Evaluate               ${DOC_COUNTER} + 1
    Set Suite Variable    ${DOC_COUNTER}         ${new}
    ${as_str}=            Convert To String      ${new}
    RETURN                ${as_str}

Current DateTime ISO
    [Documentation]    ISO 8601 timestamp για το dateIssued
    ${now}=               Get Current Date       result_format=%Y-%m-%dT%H:%M:%S
    RETURN                ${now}

Reset Pending Marks Pool
    @{empty}=             Create List
    Set Test Variable     @{PENDING_MARKS}       @{empty}

# ======================================================================
# 8.6 operations
# ======================================================================

Send 8.6 Debit
    [Arguments]           ${gross}    ${vat_rate}=${DEFAULT_VAT_RATE}
    ${payload}=           Copy Dictionary        ${TPL_8_6}    deepcopy=True
    ${payload}=           Build 8 6 Payload      ${payload}    ${gross}    ${vat_rate}    record_type_code=${0}
    ${mark}=              POST 8.6 Document      ${payload}
    Append To List        ${PENDING_MARKS}       ${mark}
    Log                   8.6 DEBIT gross=${gross} vat=${vat_rate}% -> MARK ${mark} | pool=${PENDING_MARKS}
    RETURN                ${mark}

Send 8.6 Credit
    [Arguments]           ${gross}    ${vat_rate}=${DEFAULT_VAT_RATE}
    ${payload}=           Copy Dictionary        ${TPL_8_6_CREDIT}    deepcopy=True
    ${payload}=           Build 8 6 Payload      ${payload}    ${gross}    ${vat_rate}    record_type_code=${7}
    ${mark}=              POST 8.6 Document      ${payload}
    Append To List        ${PENDING_MARKS}       ${mark}
    Log                   8.6 CREDIT gross=${gross} vat=${vat_rate}% -> MARK ${mark} | pool=${PENDING_MARKS}
    RETURN                ${mark}

Send 8.6 Cancel
    [Arguments]           @{marks_to_cancel}
    [Documentation]       Ακυρώνει συγκεκριμένα 8.6 MARKs (debit ή credit).
    ...                   Χωρίς ορίσματα = ακυρώνει όλα τα pending. Τα ακυρωμένα αφαιρούνται από το pool.
    ${count}=             Get Length             ${marks_to_cancel}
    IF    ${count} == 0
        @{marks_to_cancel}=    Copy List         ${PENDING_MARKS}
    END
    ${payload}=           Copy Dictionary        ${TPL_8_6_CANCEL}    deepcopy=True
    ${payload}=           Build 8 6 Cancel Payload    ${payload}    ${marks_to_cancel}
    ${mark}=              POST 8.6 Document      ${payload}
    Remove Marks From Pool    ${marks_to_cancel}
    Log                   8.6 CANCEL cancels=${marks_to_cancel} -> MARK ${mark} | pool=${PENDING_MARKS}
    RETURN                ${mark}

# ======================================================================
# 11.1 / 11.4 operations
# ======================================================================

Send 11.1 Debit
    [Arguments]           ${gross}    ${expected_marks_count}=${NONE}
    ...                   ${vat_rate}=${DEFAULT_VAT_RATE}
    ...                   ${close_all_pending}=${True}    ${peek}=${False}
    ${marks_to_use}=      Pop Marks From Pool    close_all=${close_all_pending}    peek=${peek}
    IF    $expected_marks_count is not None
        Length Should Be    ${marks_to_use}    ${expected_marks_count}
    END
    ${payload}=           Copy Dictionary        ${TPL_11_1}    deepcopy=True
    ${payload}=           Build 11 1 Payload     ${payload}    ${gross}    ${marks_to_use}
    ...                                          invoice_type_code=11.1    record_type_code=${0}
    ...                                          vat_rate=${vat_rate}
    ${mark}=              POST 11.1 Document     ${payload}
    Log                   11.1 DEBIT gross=${gross} connects=${marks_to_use} -> MARK ${mark}
    RETURN                ${mark}

Send 11.4 Credit
    [Arguments]           ${gross}    ${expected_marks_count}=${NONE}
    ...                   ${vat_rate}=${DEFAULT_VAT_RATE}    ${close_all_pending}=${True}
    ...                   ${peek}=${False}                            # ← πρόσθεσε
    ${marks_to_use}=      Pop Marks From Pool    close_all=${close_all_pending}    peek=${peek}  # ← πρόσθεσε
    ${payload}=           Copy Dictionary        ${TPL_11_1}    deepcopy=True
    ${payload}=           Build 11 1 Payload     ${payload}    ${gross}    ${marks_to_use}
    ...                                          invoice_type_code=11.4    record_type_code=${0}
    ...                                          vat_rate=${vat_rate}
    ${mark}=              POST 11.1 Document     ${payload}
    Log                   11.4 CREDIT gross=${gross} connects=${marks_to_use} -> MARK ${mark}
    RETURN                ${mark}

# ======================================================================
# Payload builders
# ======================================================================

Build 8 6 Payload
    [Arguments]           ${template}    ${gross}    ${vat_rate}    ${record_type_code}=${0}
    [Documentation]       Γεμίζει 8.6 payload με σωστά VAT calculations + unique number + current datetime
    ${doc_number}=        Next Document Number
    ${now}=               Current DateTime ISO
    Set To Dictionary     ${template}    number=${doc_number}    dateIssued=${now}
    ...                                  tableId=${TABLE_ID}
    Apply Issuer Vat      ${template}
    Apply Line And Summaries    ${template}    ${gross}    ${vat_rate}    ${record_type_code}
    RETURN                ${template}

Build 11 1 Payload
    [Arguments]           ${template}    ${gross}    ${marks}
    ...                   ${invoice_type_code}=11.1    ${record_type_code}=${0}
    ...                   ${vat_rate}=${DEFAULT_VAT_RATE}
    [Documentation]       Γεμίζει 11.1 ή 11.4 (ίδιο schema). Βάζει MARKs στο multipleConnectedMarks.
    ${doc_number}=        Next Document Number
    ${now}=               Current DateTime ISO
    Set To Dictionary     ${template}    number=${doc_number}    dateIssued=${now}
    ...                                  InvoiceTypeCode=${invoice_type_code}
    Set To Dictionary     ${template}    multipleConnectedMarks=${marks}
    Apply Issuer Vat      ${template}
    Apply Line And Summaries    ${template}    ${gross}    ${vat_rate}    ${record_type_code}
    RETURN                ${template}

Build 8 6 Cancel Payload
    [Arguments]           ${template}    ${marks_to_cancel}
    [Documentation]       Cancel 8.6: Quantity=1 αλλά όλα τα ποσά=0, totalCancelDeliveryOrders=true.
    ${doc_number}=        Next Document Number
    ${now}=               Current DateTime ISO
    Set To Dictionary     ${template}    number=${doc_number}    dateIssued=${now}
    ...                                  tableId=${TABLE_ID}
    ...                                  totalCancelDeliveryOrders=${True}
    ...                                  multipleConnectedMarks=${marks_to_cancel}
    Apply Issuer Vat      ${template}
    Zero Out Line And Summaries    ${template}
    RETURN                ${template}

Apply Issuer Vat
    [Arguments]           ${payload}
    [Documentation]       Αντικαθιστά το Issuer.Vat στο payload με την τιμή της ${ISSUER_VAT}.
    ${issuer}=            Get From Dictionary    ${payload}    Issuer
    Set To Dictionary     ${issuer}    Vat=${ISSUER_VAT}

# ======================================================================
# VAT / Line / Summary helpers
# ======================================================================

Apply Line And Summaries
    [Arguments]           ${payload}    ${gross}    ${vat_rate}    ${record_type_code}
    [Documentation]       Υπολογίζει και γεμίζει: Line (Quantity, UnitPrice, NetTotal, VATTotal, Total,
    ...                   VatCategory, VatCategoryCode), Summaries, VatAnalysis.
    ...                   Ακόμα και όταν gross=0, διατηρεί το vat_rate του χρήστη ώστε το
    ...                   VatCategoryCode να ταιριάζει με τα συσχετιζόμενα 8.6.
    ${breakdown}=         Calculate VAT Breakdown    ${gross}    ${vat_rate}
    ${cat}=               Map VAT Rate To Category   ${vat_rate}
    ${net}=               Set Variable           ${breakdown}[net]
    ${vat}=               Set Variable           ${breakdown}[vat]
    ${gross_amt}=         Set Variable           ${breakdown}[gross]

    # --- Γραμμή ---
    ${details}=           Get From Dictionary    ${payload}    Details
    ${first_line}=        Get From List          ${details}    0
    Set To Dictionary     ${first_line}
    ...    code=${PRODUCT_CODE}
    ...    Quantity=${1}
    ...    UnitPrice=${net}
    ...    allowancesTotal=${0.0}
    ...    NetTotal=${net}
    ...    VatCategory=${cat}[VatCategory]
    ...    VatCategoryCode=${cat}[VatCategoryCode]
    ...    VATTotal=${vat}
    ...    Total=${gross_amt}
    ...    RecordTypeCode=${record_type_code}

    # --- Summaries ---
    ${summaries}=         Create Dictionary
    ...    totalAllowances=${0.0}
    ...    TotalNetAmount=${net}
    ...    TotalVATAmount=${vat}
    ...    TotalGrossValue=${gross_amt}
    Set To Dictionary     ${payload}    Summaries=${summaries}

    # --- VatAnalysis ---
    ${vat_entry}=         Create Dictionary
    ...    Percentage=${vat_rate}
    ...    VatAmount=${vat}
    ...    UnderlyingValue=${net}
    @{vat_analysis}=      Create List            ${vat_entry}
    Set To Dictionary     ${payload}    VatAnalysis=${vat_analysis}

Zero Out Line And Summaries
    [Arguments]           ${payload}
    [Documentation]       Cancel 8.6: Quantity=1 (placeholder record) με όλα τα ποσά = 0.
    ...                   VatCategory="0", VatCategoryCode=8 (καμία φορολόγηση).
    ${details}=           Get From Dictionary    ${payload}    Details
    ${first_line}=        Get From List          ${details}    0
    Set To Dictionary     ${first_line}
    ...    Quantity=${1}
    ...    UnitPrice=${0}
    ...    allowancesTotal=${0.0}
    ...    NetTotal=${0}
    ...    VatCategory=0
    ...    VatCategoryCode=${8}
    ...    VATTotal=${0}
    ...    Total=${0}
    ...    RecordTypeCode=${0}
    ${summaries}=         Create Dictionary
    ...    totalAllowances=${0.0}
    ...    TotalNetAmount=${0.0}
    ...    TotalVATAmount=${0.0}
    ...    TotalGrossValue=${0.0}
    Set To Dictionary     ${payload}    Summaries=${summaries}
    ${vat_entry}=         Create Dictionary
    ...    Percentage=${0.0}
    ...    VatAmount=${0.0}
    ...    UnderlyingValue=${0.0}
    @{vat_analysis}=      Create List            ${vat_entry}
    Set To Dictionary     ${payload}    VatAnalysis=${vat_analysis}

Calculate VAT Breakdown
    [Arguments]           ${gross}    ${vat_rate}
    [Documentation]       Από gross + rate υπολογίζει net και vat με rounding στο 2ο δεκαδικό.
    ...                   Κανόνας: net = gross / (1 + rate/100), vat = gross - net.
    ${net}=               Evaluate    round(${gross} / (1 + ${vat_rate}/100.0), 2)
    ${vat}=               Evaluate    round(${gross} - ${net}, 2)
    ${gross_f}=           Evaluate    float(${gross})
    ${result}=            Create Dictionary      net=${net}    vat=${vat}    gross=${gross_f}
    RETURN                ${result}

Map VAT Rate To Category
    [Arguments]           ${vat_rate}
    [Documentation]       Mapping: 24->1, 13->2, 0->8 (βάσει των δικών σου templates).
    ...                   Επέκτεινε αν χρειαστείς άλλους κωδικούς.
    ${map}=               Create Dictionary
    ...    24=${1}    13=${2}    6=${3}    17=${4}    9=${5}    4=${6}    5=${7}    0=${8}
    ${rate_str}=          Convert To String      ${vat_rate}
    ${code}=              Get From Dictionary    ${map}    ${rate_str}    default=${8}
    ${result}=            Create Dictionary      VatCategory=${rate_str}    VatCategoryCode=${code}
    RETURN                ${result}

# ======================================================================
# Pool helpers
# ======================================================================

Pop Marks From Pool
    [Arguments]           ${close_all}=${True}    ${peek}=${False}
    IF    ${peek}                                   # ← peek ΠΡΩΤΑ
        @{marks}=         Copy List              ${PENDING_MARKS}
        # pool ΔΕΝ αλλάζει
    ELSE IF    ${close_all}
        @{marks}=         Copy List              ${PENDING_MARKS}
        @{empty}=         Create List
        Set Test Variable    @{PENDING_MARKS}    @{empty}
    ELSE
        ${half}=          Evaluate               len($PENDING_MARKS)//2 or 1
        @{marks}=         Evaluate               $PENDING_MARKS[:${half}]
        @{rest}=          Evaluate               $PENDING_MARKS[${half}:]
        Set Test Variable    @{PENDING_MARKS}    @{rest}
    END
    RETURN                @{marks}

Remove Marks From Pool
    [Arguments]           ${marks_to_remove}
    [Documentation]       Αφαιρεί τα δοσμένα MARKs από το pending pool.
    ...                   Σημείωση: τα MARKs είναι integers (π.χ. 400001961636061),
    ...                   οπότε χρησιμοποιούμε $m (όχι '${m}') για να μην γίνει string.
    @{new_pool}=          Create List
    FOR    ${m}    IN    @{PENDING_MARKS}
        ${is_cancelled}=    Evaluate    $m in $marks_to_remove
        IF    not ${is_cancelled}
            Append To List    ${new_pool}    ${m}
        END
    END
    Set Test Variable     @{PENDING_MARKS}       @{new_pool}

Pool Should Be Empty
    Length Should Be      ${PENDING_MARKS}    ${0}
    ...                   msg=Αναμενόταν άδειο pool αλλά υπάρχουν marks: ${PENDING_MARKS}

# ======================================================================
# HTTP
# ======================================================================

POST 8.6 Document
    [Arguments]           ${payload}
    ${mark}=              Submit FNB Document    ${payload}    label=8.6
    RETURN                ${mark}

POST 11.1 Document
    [Arguments]           ${payload}
    ${mark}=              Submit FNB Document    ${payload}    label=11.1/11.4
    RETURN                ${mark}

Submit FNB Document
    [Arguments]           ${payload}    ${label}=FNB
    [Documentation]       Στέλνει το payload, λογκάρει πάντα το response, και αν υπάρχει σφάλμα
    ...                   κάνει Fail με ευανάγνωστο business message (από myDataErrors/message).
    ${resp}=              POST On Session    fnb    /invoice/json    json=${payload}
    ...                   expected_status=any
    Log Response          ${resp}    ${label}
    IF    ${resp.status_code} >= 400
        ${err_msg}=       Extract Server Error    ${resp}
        Fail              ${label} FAILED [HTTP ${resp.status_code} ${resp.reason}] >> ${err_msg}
    END
    ${body}=              Set Variable           ${resp.json()}
    ${mark}=              Get From Dictionary    ${body}    mark    default=${NONE}
    IF    $mark is None
        Fail              ${label}: response 2xx αλλά λείπει το 'mark' στο body. Body: ${body}
    END
    RETURN                ${mark}

Log Response
    [Arguments]           ${resp}    ${label}=FNB
    [Documentation]       Εμφανίζει status, reason και body στο Robot log (truncated αν είναι μεγάλο).
    ${preview}=           Truncate Text          ${resp.text}    2000
    Log                   ${label} RESPONSE [HTTP ${resp.status_code} ${resp.reason}]\n${preview}
    ...                   level=INFO

Truncate Text
    [Arguments]           ${text}    ${max_chars}=2000
    ${len}=               Get Length             ${text}
    IF    ${len} <= ${max_chars}
        RETURN            ${text}
    END
    ${trunc}=             Evaluate               $text[:${max_chars}]
    RETURN                ${trunc}... [truncated ${len} chars total]

Extract Server Error
    [Arguments]           ${resp}
    [Documentation]       Πιάνει τα πιο χρήσιμα error fields από το response body.
    ...                   Priority: message -> myDataErrors -> errorMessage -> raw text.
    ${body}=              Try Parse Json         ${resp}
    IF    $body is None
        RETURN            ${resp.text}
    END
    # 1) Γενικό message (το πιο ανθρώπινο)
    ${msg}=               Get From Dictionary    ${body}    message    default=${EMPTY}
    IF    "${msg}" != "${EMPTY}"
        RETURN            ${msg}
    END
    # 2) myDataErrors array (δομημένα errors από AADE)
    ${errors}=            Get From Dictionary    ${body}    myDataErrors    default=${EMPTY}
    ${err_count}=         Get Length             ${errors}
    IF    ${err_count} > 0
        ${joined}=        Evaluate
        ...    ' | '.join([f"[{e.get('key','?')}] {e.get('value','')}" for e in $errors])
        RETURN            ${joined}
    END
    # 3) Apla errorMessage
    ${em}=                Get From Dictionary    ${body}    errorMessage    default=${EMPTY}
    IF    "${em}" != "${EMPTY}"
        RETURN            ${em}
    END
    # 4) Fallback: όλο το body ως string
    RETURN                ${resp.text}

Try Parse Json
    [Arguments]           ${resp}
    TRY
        ${body}=          Set Variable           ${resp.json()}
        RETURN            ${body}
    EXCEPT
        RETURN            ${NONE}
    END

