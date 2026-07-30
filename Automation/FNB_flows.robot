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
TC 07.3 - Mixed Complex Flow 11.1 Debit
    [Documentation]    Το σύνθετο σενάριο με 9 βήματα (το τελευταίο είναι 11.1)
    ${m1}=    Send 8.6 Debit     gross=10        
    ${m2}=    Send 8.6 Debit     gross=30        
    ${m3}=    Send 8.6 Credit    gross=10        
    ${m4}=    Send 11.1 Debit   ${m1}    ${m2}    ${m3}     gross=20
    ${m5}=    Send 8.6 Debit     gross=30        
    ${m6}=    Send 11.1 Debit    ${m3}    ${m5}    gross=30    
    ${m7}=    Send 8.6 Debit     gross=20      
    ${m8}=    Send 8.6 Credit    gross=20      
    ${m9}=    Send 11.1 Debit    ${m5}    ${m7}    ${m8}    gross=10
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

TC 17 - Zero After Multiple Offsetting table Moves
    [Documentation]    Πολλαπλές κινήσεις που ακυρώνονται μεταξύ τους. Τα 8.6 είναι 13%,
    ...                άρα το μηδενικό 11.1 πρέπει επίσης να φέρει VatCategoryCode=2.
    ${m1}=    Send 8.6 Debit     gross=100    vat_rate=${13}
    ${m2}=    Send 11.1 Debit    ${m1}          gross=70    vat_rate=${13}
   # Sleep    1 minutes
    ${m3}=    Send 8.6 Credit    ${m1}          gross=70    vat_rate=${13}
  #  Sleep    1 minutes
    ${m4}=    Send 11.4 Credit   ${m1}    ${m3}    gross=70    vat_rate=${13}
    ${m5}=    Send 11.1 Debit    ${m1}    ${m3}    gross=30    vat_rate=${13}
    Sleep    1 minutes
    ${m6}=    Send 8.6 Credit    ${m1}          gross=30    vat_rate=${13}
    ${m7}=    Send 11.4 Credit   ${m1}    ${m6}    gross=30    vat_rate=${13}

 TC 18 - Cross-Linked FNB Marks Over Successive Rounds
    [Documentation]    Πολλαπλές κινήσεις που ακυρώνονται μεταξύ τους. Τα 8.6 είναι 13%,
    ...                άρα το μηδενικό 11.1 πρέπει επίσης να φέρει VatCategoryCode=2.
    ${m1}=    Send 8.6 Debit     gross=100    vat_rate=${13}
    ${m2}=    Send 11.1 Debit    ${m1}          gross=70    vat_rate=${13}
    ${m3}=    Send 8.6 Credit    ${m1}          gross=70    vat_rate=${13}
   # Sleep    1 minutes
    ${m4}=    Send 11.4 Credit   ${m3}          gross=70    vat_rate=${13}
    ${m5}=    Send 11.1 Debit    ${m3}          gross=30    vat_rate=${13}
    ${m6}=    Send 8.6 Credit    ${m3}          gross=30    vat_rate=${13}
   #  Sleep    1 minutes
    ${m7}=    Send 11.4 Credit   ${m6}          gross=30    vat_rate=${13}  
    ${m8}=    Send 8.6 Debit     ${m6}          gross=80    vat_rate=${13}
   #  Sleep    1 minutes
    ${m9}=    Send 11.1 Debit    ${m8}          gross=80    vat_rate=${13}
    ${m10}=    Send 8.6 Credit    ${m8}         gross=80    vat_rate=${13}
   #  Sleep    1 minutes
    ${m11}=    Send 8.6 Debit     ${m10}         gross=20    vat_rate=${13}
     Sleep    1 minutes
    ${m12}=    Send 11.1 Debit    ${m11}         gross=20    vat_rate=${13}
    ${m13}=    Send 8.6 Credit    ${m11}         gross=20    vat_rate=${13}
    ${m14}=    Send 11.1 Debit    ${m13}         gross=20    vat_rate=${13}
    ${m15}=    Send 8.6 Credit    ${m13}         gross=20    vat_rate=${13}

 TC 19 - Cross-Linked FNB Marks Over Successive Rounds
    [Documentation]    Πολλαπλές κινήσεις που ακυρώνονται μεταξύ τους. Τα 8.6 είναι 13%,
    ...                άρα το μηδενικό 11.1 πρέπει επίσης να φέρει VatCategoryCode=2.
    ${m1}=    Send 8.6 Debit     gross=100    vat_rate=${13}
    ${m2}=    Send 11.1 Debit    ${m1}          gross=70    vat_rate=${13}
    ${m3}=    Send 11.1 Debit    ${m1}          gross=29.90    vat_rate=${13}

*** Settings ***
Documentation     FNB (Food & Beverage) Table Order Scenarios — 8.6 Δελτίο Παραγγελίας Εστίασης
...
...               Υλοποίηση / mapping στο suite:
...               - Send 8.6 Debit  = ΔΠΕ κανονικό πρόσημο (record_type_code=0)· MARK στο pool.
...               - Send 8.6 Credit = ΔΠΕ αντίθετο πρόσημο / μερική ακύρωση (record_type_code=7).
...               - Send 8.6 Cancel = «Καθολική Ακύρωση 8.6» (χωρίς αξία, Quantity=1)· αφαιρεί MARKs.
...               - Send 11.1 Debit = ΑΛΠ που κλείνει τα pending 8.6 μέσω multipleConnectedMarks.
...               - Send 11.4 Credit= Πιστωτικό Στοιχείο Λιανικής (ίδιο schema με 11.1, άλλος InvoiceTypeCode).
...
...               ==========================================================================
...               ΚΑΝΟΝΕΣ ΚΛΕΙΣΙΜΑΤΟΣ 8.6 ΜΕ ΤΑ ΠΑΡΑΣΤΑΤΙΚΑ ΑΞΙΑΣ (myDATA)
...               Α.1138/2020 όπως τροπ. με Α.1170/2023
...               ==========================================================================
...
...               *1. Με ποια παραστατικά κλείνει το 8.6*
...               Συσχετίζεται με παραστατικά αξίας που φέρουν ΥΠΟΧΡΕΩΤΙΚΑ την ένδειξη
...               «Συναλλαγές Εστίασης»:
...               - 11.1 ΑΛΠ .................. χρεωστικές λιανικής
...               - 11.4 Πιστωτικό Στοιχείο Λιανικής .. πιστωτικές λιανικής (επιστροφές/διορθώσεις)
...               - 1.1 Τιμολόγιο Πώλησης ..... χρεωστικές χονδρικής
...               - 5.1 / 5.2 Πιστωτικά Τιμολόγια .... πιστωτικές χονδρικής
...
...               *2. Κανόνας ισότητας (προϋπόθεση συσχέτισης)*
...               Η συσχέτιση νοείται ΜΟΝΟ όταν, ανά συναλλαγή εστίασης:
...               άθροισμα καθαρών αξιών & ποσοτήτων ειδών του 8.6 = αντίστοιχο άθροισμα
...               καθαρής/συνολικής αξίας & ποσοτήτων των συσχετιζόμενων χρεωστικών + πιστωτικών.
...               Ελέγχεται ΚΑΙ σε αξία ΚΑΙ σε ποσότητα, με όρια στρογγυλοποίησης 0,10 λεπτά.
...               (Γι' αυτό τα TC με gross=0: όταν 8.6 debit = 8.6 credit το άθροισμα μηδενίζεται.)
...
...               *3. Προθεσμία — 24 ώρες*
...               - Εντός 24 ωρών από ημ/ώρα έκδοσης πρέπει να συσχετιστούν & κλείσουν τα ανοιχτά 8.6.
...               - Αν μείνει ανοιχτό έστω ένα ΔΠΕ, ΔΕΝ επιτρέπονται επόμενες συναλλαγές εστίασης:
...                 με ΦΗΜ διακοπή ανά ΦΗΜ· με Πάροχο διακοπή ανά Α/Α Εγκατάστασης.
...               - Ετησίως: κλείσιμο όλων έως την υποβολή δήλωσης φορολογίας εισοδήματος.
...
...               *4. Ακυρώσεις παραγγελίας*
...               - Καθολική: ένδειξη «Καθολική Ακύρωση 8.6» → κλείνει χωρίς περαιτέρω συσχέτιση.
...               - Μερική: νέο 8.6 με αντίθετα πρόσημα (Rec Type 7) ανά είδος, εντός 24 ωρών,
...                 μόνο για τα είδη που επιστρέφονται/διορθώνονται/κέρασμα/έκπτωση.
...               - Κανονικά & αντίθετα (Rec Type 7) πρόσημα ΔΕΝ συμψηφίζονται στο ίδιο παραστατικό.
...
...               *5. Σειρά ενεργειών κλεισίματος (6 βήματα)*
...               1. Έκδοση 8.6 με κανονικό πρόσημο για τα παραγγελθέντα είδη.
...               2. Καθολική ακύρωση → «Καθολική Ακύρωση 8.6» εντός 24h (κλείνει).
...               3. Μερική ακύρωση → 8.6 με Rec Type 7 (επιστροφή/διόρθωση/κέρασμα/έκπτωση).
...               4. Συσχέτιση ειδών ώστε τα ακυρωμένα να ΜΗΝ ληφθούν υπόψη στο άθροισμα.
...               5. Άθροιση ειδών/ποσοτήτων που έμειναν με κανονικό πρόσημο.
...               6. Έκδοση ΑΛΠ/Τιμολογίου που κλείνει & συσχετίζει τα 8.6 (κανονικά + Rec Type 7).
...               Εναλλακτικά, η μερική ακύρωση ολοκληρώνεται με Πιστωτικές Αποδείξεις Λιανικής (11.4).
...
...               *6. Υποχρεώσεις Παρόχου*
...               Τεκμηριώνει ότι όλα τα ανοιχτά 8.6 συσχετίστηκαν εντός 24h, ότι τα παραστατικά αξίας
...               φέρουν «Συναλλαγές Εστίασης (12)», και σε μη-κλεισμένο 8.6 διακόπτει τη διαβίβαση
...               ανά Α/Α Εγκατάστασης.

Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           DateTime
Library           String
Variables         ${EXECDIR}/config/credentials.py
Suite Setup       Setup Suite
Test Setup        Reset Pending Marks Pool

*** Variables ***
${BASE_URL}                ${UAT_API}
${TEMPLATE_8_6}            ${CURDIR}/Data/8.6_Debit_FNB_Form.json
${TEMPLATE_8_6_CREDIT}     ${CURDIR}/Data/8.6_Return_FNB_Form.json
${TEMPLATE_8_6_CANCEL}     ${CURDIR}/Data/8.6_Cancel_FNB_Form.json
${TEMPLATE_11_1}           ${CURDIR}/Data/11.1_FNB_Retail_Sales_Receipt.json
${TABLE_ID}                20
${DEFAULT_VAT_RATE}        ${13}
${PRODUCT_CODE}            251320104
${API_KEY}                 ${EINVOICE_API_KEY}
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
    [Arguments]           @{connects}    ${gross}    ${vat_rate}=${DEFAULT_VAT_RATE}
    [Documentation]       Τα προαιρετικά positional MARKs (@{connects}) μπαίνουν στο
    ...                   multipleConnectedMarks του request.
    ${payload}=           Copy Dictionary        ${TPL_8_6}    deepcopy=True
    ${payload}=           Build 8 6 Payload      ${payload}    ${gross}    ${vat_rate}
    ...                                          record_type_code=${0}    marks=${connects}
    ${mark}=              POST 8.6 Document      ${payload}
    Append To List        ${PENDING_MARKS}       ${mark}
    Log                   8.6 DEBIT gross=${gross} vat=${vat_rate}% connects=${connects} -> MARK ${mark} | pool=${PENDING_MARKS}
    RETURN                ${mark}

Send 8.6 Credit
    [Arguments]           @{connects}    ${gross}    ${vat_rate}=${DEFAULT_VAT_RATE}
    [Documentation]       Τα προαιρετικά positional MARKs (@{connects}) μπαίνουν στο
    ...                   multipleConnectedMarks του request.
    ${payload}=           Copy Dictionary        ${TPL_8_6_CREDIT}    deepcopy=True
    ${payload}=           Build 8 6 Payload      ${payload}    ${gross}    ${vat_rate}
    ...                                          record_type_code=${7}    marks=${connects}
    ${mark}=              POST 8.6 Document      ${payload}
    Append To List        ${PENDING_MARKS}       ${mark}
    Log                   8.6 CREDIT gross=${gross} vat=${vat_rate}% connects=${connects} -> MARK ${mark} | pool=${PENDING_MARKS}
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
    [Arguments]           @{connects}    ${gross}    ${expected_marks_count}=${NONE}
    ...                   ${vat_rate}=${DEFAULT_VAT_RATE}
    ...                   ${close_all_pending}=${True}    ${peek}=${False}
    [Documentation]       Αν δοθούν positional MARKs (@{connects}), χρησιμοποιούνται αυτά
    ...                   ρητά. Αλλιώς αντλεί από το pool (παλιά συμπεριφορά).
    IF    ${connects}
        ${marks_to_use}=      Set Variable           ${connects}
    ELSE
        ${marks_to_use}=      Pop Marks From Pool    close_all=${close_all_pending}    peek=${peek}
    END
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
    [Arguments]           @{connects}    ${gross}    ${expected_marks_count}=${NONE}
    ...                   ${vat_rate}=${DEFAULT_VAT_RATE}    ${close_all_pending}=${True}
    ...                   ${peek}=${False}
    [Documentation]       Αν δοθούν positional MARKs (@{connects}), χρησιμοποιούνται αυτά
    ...                   ρητά. Αλλιώς αντλεί από το pool (παλιά συμπεριφορά).
    IF    ${connects}
        ${marks_to_use}=      Set Variable           ${connects}
    ELSE
        ${marks_to_use}=      Pop Marks From Pool    close_all=${close_all_pending}    peek=${peek}
    END
    IF    $expected_marks_count is not None
        Length Should Be    ${marks_to_use}    ${expected_marks_count}
    END
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
    [Arguments]           ${template}    ${gross}    ${vat_rate}    ${record_type_code}=${0}    ${marks}=${NONE}
    [Documentation]       Γεμίζει 8.6 payload με σωστά VAT calculations + unique number + current datetime.
    ...                   Αν δοθεί ${marks}, τα βάζει στο multipleConnectedMarks.
    ${doc_number}=        Next Document Number
    ${now}=               Current DateTime ISO
    Set To Dictionary     ${template}    number=${doc_number}    dateIssued=${now}
    ...                                  tableId=${TABLE_ID}
    IF    $marks is not None
        Set To Dictionary     ${template}    multipleConnectedMarks=${marks}
    END
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

