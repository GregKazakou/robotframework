*** Settings ***
Documentation   Hotdog
Library         SeleniumLibrary
Variables       ${EXECDIR}/config/credentials.py
Suite Setup     Open Headless Browser
Suite Teardown  Close Browser Session

*** Variables ***
${urlHotdog}      https://hotdoc.impact.gr/
${Browser1}         Chrome
${HEADLESS}         False    # Τοπικά False, στο GitHub True
# Λογαριασμός / στοιχεία από config/credentials.py — ποτέ hardcoded εδώ
${userEmail1}     ${HOTDOG_USER_EMAIL}
${pwd1}           ${HOTDOG_PASSWORD}
${companyTIN1}    ${HOTDOG_COMPANY_TIN}
${newUserName}      ${HOTDOG_NEW_USER_NAME}
${newUserEmail}     ${HOTDOG_NEW_USER_EMAIL}
${INVALID_EMAIL}    mhtsos@something.com

${LOGIN_LINK}    xpath=//a[@href="/auth/login"]
${SEARCH_INPUT}    xpath=//input[@placeholder="Αναζήτηση εταιρίας μέσω ΑΦΜ"]
${SUCCESS_LOGIN_URL}    https://hotdoc.impact.gr/company/select?redirectUrl=%2F

${USERNAME_FIELD}    id=emailInput
${PASSWORD_FIELD}    name=LoginInput.Password
${LOGIN_BUTTON}      id=loginButton
${LOGIN_URL}    https://hotdoc.impact.gr/auth/login
${newCompanyName}      ${HOTDOG_COMPANY_NAME}
${expectedAadeUser}    ${HOTDOG_EXPECTED_AADE_USER}
${BASE_URL}             https://hotdoc.impact.gr

# ======================================
# --- DocPilot feature selectors & data ---
# (data-slot attributes + Lucide icon classes — επιβεβαιωμένα από live UI)
# ======================================
# Demo company VATs — override στο config/credentials.py αν χρειαστεί
${CO_LMC_VAT}          118058830
${CO_VDM_VAT}          127913129
${CO_PAPAKI_VAT}       135952929
${CO_GREGK_VAT}        154697391
${CO_SIMPLE_VAT}       999840150

# Sidebar navigation
${NAV_HOME}            xpath=//button[@data-slot='sidebar-menu-button' and normalize-space(.)='Αρχική']
${NAV_DOCUMENTS}       xpath=//button[@data-slot='sidebar-menu-button' and normalize-space(.)='Παραστατικά']
${MENU_MANAGEMENT}     xpath=//button[@data-slot='collapsible-trigger' and normalize-space(.)='Διαχείριση']
${MENU_HISTORY}        xpath=//button[@data-slot='collapsible-trigger' and normalize-space(.)='Ιστορικό']

# Documents list
${DOCS_URL}            ${BASE_URL}/invoices/incoming
${DN_FILTER_URL}       ${BASE_URL}/invoices/incoming?From=2024-01-01&IsDeliveryNote=true
${SEARCH_BUTTON}       xpath=//button[@data-slot='button' and normalize-space(.)='Αναζήτηση']
${AI_SCHEMA_BUTTON}    xpath=//button[normalize-space(.)='Δοκιμή με AI Schema']
${VIEW_LINK_FIRST}     xpath=(//a[normalize-space(.)='Προβολή'])[1]
${DATE_FROM}           xpath=(//input[@placeholder='dd/MM/yyyy'])[1]
${DATE_TO}             xpath=(//input[@placeholder='dd/MM/yyyy'])[2]
${ROW_CHECKBOX_FIRST}  xpath=(//button[@data-slot='checkbox' and @aria-label='Select row'])[1]

# Document view (Εικόνα Παραστατικού) toolbar
${VIEW_PORTAL_LINK}    xpath=//a[contains(@href,'einvoice-demo-portal')]
${VIEW_MYDATA_LINK}    xpath=//a[contains(@href,'mydata')]
${VIEW_XML_LINK}       xpath=//a[contains(@href,'/xml/raw')]
${VIEW_PRINT_BTN}      xpath=//button[.//*[contains(@class,'lucide-printer')]]
${VIEW_ARCHIVE_BTN}    xpath=//button[.//*[contains(@class,'lucide-archive')]]
# Ενέργειες Παραλαβής — μόνο Warehouse Manager (εικονίδιο package/box).
# ΠΡΟΣΟΧΗ: αν αλλάξει το εικονίδιο στο UI, προσαρμόσε την κλάση εδώ.
${RECEIPT_TRIGGER}     xpath=//button[@data-slot='dropdown-menu-trigger' and @aria-haspopup='menu'][.//*[contains(@class,'lucide-package')]]
${RECEIPT_CONFIRM}     xpath=//*[@role='menuitem' and normalize-space(.)='Επιβεβαίωση Παραλαβής']
${RECEIPT_PARTIAL}     xpath=//*[@role='menuitem' and normalize-space(.)='Επιβεβαίωση Μερικής Παραλαβής']
${RECEIPT_REJECT}      xpath=//*[@role='menuitem' and contains(normalize-space(.),'Ολική Απόρριψη')]

# Μενού Διαχείρισης (υπο-σύνδεσμοι)
${MGMT_USERS}          xpath=//a[@href='/account/manage']
# Τρέχον UI (Οκτ 2026): ο σύνδεσμος «Διαχείριση Εταιρείας» μετονομάστηκε σε
# «Ρύθμιση» (ίδιο href /company/manage). Επιλογή με href για ανθεκτικότητα.
${MGMT_COMPANY}        xpath=//a[@href='/company/manage']
${MGMT_PACKAGES}       xpath=//a[normalize-space(.)='Προαγορασμένα πακέτα']
${MGMT_CUSTOM_FIELDS}  xpath=//a[normalize-space(.)='Προσαρμοσμένα Πεδία']
${MGMT_API_KEYS}       xpath=//a[normalize-space(.)='Κλειδιά API']
${MGMT_API_DOCS}       xpath=//a[normalize-space(.)='Τεκμηρίωση API']
${HISTORY_SYNC}        xpath=//a[normalize-space(.)='Ιστορικό Συγχρονισμού']

# Επιλογή εταιρείας (τρέχον UI)
${CO_SELECT_URL}       ${BASE_URL}/company/select
# Τρέχον UI (Οκτ 2026): το πεδίο αναζήτησης στο /company/select είναι
# <input type="search" placeholder="Όνομα ή ΑΦΜ">. Παλιό placeholder
# 'Αναζήτηση εγκατάστασης' δεν υπάρχει πλέον.
${CO_SEARCH_INPUT}     xpath=//input[@type='search' and contains(@placeholder,'Όνομα ή ΑΦΜ')]
${CO_ENTER_BTN_FIRST}  xpath=(//button[contains(@aria-label,'Είσοδος στην εταιρεία')])[1]

*** Keywords ***
# ======================================
# ---------------- HELPERS -------------
# ======================================
Scroll To Center
    [Documentation]    Scrolls the element to the CENTER of the viewport.
    ...                (Plain Scroll Element Into View aligns it to the top,
    ...                where the app's sticky header intercepts clicks.)
    [Arguments]    ${locator}
    ${el}=    Get WebElement    ${locator}
    Execute Javascript    arguments[0].scrollIntoView({block: 'center', inline: 'nearest'});
    ...    ARGUMENTS    ${el}

Attempt Click
    [Arguments]    ${locator}
    Scroll To Center    ${locator}
    Element Should Be Visible    ${locator}
    Element Should Be Enabled    ${locator}
    Click Element    ${locator}

Safe Click
    [Arguments]    ${locator}    ${timeout}=10s

    ${status}    ${err}=    Run Keyword And Ignore Error
    ...    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Attempt Click    ${locator}

    IF    '${status}' != 'PASS'
        # Last resort: JS click — bypasses overlays (sticky header/toasts)
        # that intercept the native click even when the element is visible.
        Log    Native click failed (${err}) — falling back to JS click.    WARN
        ${el}=    Get WebElement    ${locator}
        Execute Javascript    arguments[0].click();    ARGUMENTS    ${el}
    END

Safe Wait Element
    [Arguments]    ${locator}    ${timeout}=10s

    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Run Keywords
    ...    Scroll To Center    ${locator}
    ...    AND    Element Should Be Visible    ${locator}
    ...    AND    Element Should Be Enabled    ${locator}

Safe Input Text
    [Arguments]    ${locator}    ${text}    ${timeout}=10s
    # Re-locate ΜΕΣΑ στο retry: σε SPA re-render το element γίνεται stale
    # ανάμεσα στο wait και στο clear/input (StaleElementReferenceException).
    Wait Until Keyword Succeeds    ${timeout}    500ms    Type Into Field    ${locator}    ${text}

Type Into Field
    [Arguments]    ${locator}    ${text}
    Scroll To Center     ${locator}
    Element Should Be Visible    ${locator}
    Clear Element Text   ${locator}
    Input Text           ${locator}    ${text}

Wait For Page Ready
    # Basic “page loaded” check
    Wait Until Page Contains Element    xpath=//body    10s

Expand Menu By Text
    [Arguments]    ${menu_name}
    # Τρέχον UI: το μενού είναι collapsible-trigger (όχι //button//span).
    ${MENU}    Set Variable
    ...    xpath=//button[@data-slot='collapsible-trigger' and normalize-space(.)='${menu_name}']
    Safe Wait Element    ${MENU}
    ${expanded}=    Get Element Attribute    ${MENU}    aria-expanded
    IF    '${expanded}' != 'true'
        Safe Click    ${MENU}
    END

Click Menu Item By Name
    [Arguments]    ${item_name}
    Wait Until Element Is Visible    xpath=//a[normalize-space()="${item_name}"]
    Click Element    xpath=//a[normalize-space()="${item_name}"]
# ======================================
# ---------------- SUITE -------------
# ======================================

Open Headless Browser
    IF    '${HEADLESS}' == 'True'
        # Fixed large viewport: headless "maximize" is 800x600, which
        # triggers the responsive layout and click interception.
        Open Browser    ${urlHotdog}    ${Browser1}
        ...    options=add_argument("--headless=new");add_argument("--window-size=1920,1080")
    ELSE
        Open Browser    ${urlHotdog}    ${Browser1}
    END
    # Επιβάλλουμε ΡΗΤΑ μεγάλο viewport. Το «Maximize Browser Window» σε headless
    # είναι αναξιόπιστο (καταλήγει ~800x600) και ενεργοποιεί το responsive layout,
    # που ΚΡΥΒΕΙ το sidebar «Διαχείριση» και τα φίλτρα παραστατικών -> fail σε
    # TC 03/04/06/07/08/09/10. Το Set Window Size δουλεύει και σε headless (CDP).
    Set Window Size    1920    1080
    Go To    ${urlHotdog}auth/login
    Wait Until Page Contains Element    ${USERNAME_FIELD}    15s


Open Browser To App
    [Arguments]    ${url}    ${browser}
    Open Browser    ${url}    ${browser}
    Maximize Browser Window

Close Browser Session
    Close All Browsers

# ======================================
# ---------------- LOGIN ---------------
# ======================================
Test Login
    [Arguments]    ${username}    ${password}

    Safe Wait Element    ${USERNAME_FIELD}
    Input Text    ${USERNAME_FIELD}    ${username}
    Safe Click    ${LOGIN_BUTTON}
    Wait Until Element Is Visible    ${PASSWORD_FIELD}
    Input Password    ${PASSWORD_FIELD}    ${password}
    Safe Click    ${LOGIN_BUTTON}

Valid Login Test

    [Arguments]    ${username}    ${password}
    Test Login    ${username}    ${password}
    Wait For Page Ready
    # Μετά τη μετάβαση σε ES1 Identity (OIDC SSO) το τελικό URL μετά το login
    # περιλαμβάνει πρόσθετα query params (π.χ. redirectUrl/state) και δεν είναι
    # πλέον ακριβώς το ${SUCCESS_LOGIN_URL}. Ελέγχουμε ότι προσγειωθήκαμε στη
    # σελίδα επιλογής εταιρείας με substring match (ανθεκτικό σε query string).
    Wait Until Location Contains    /company/select    30s

# ======================================
# ----------- COMPANY SELECT -----------
# ======================================

Select Company
    [Documentation]    Μπαίνει στην εταιρεία με το δοσμένο ΑΦΜ. Τρέχον UI: οι εταιρείες
    ...                ομαδοποιούνται ανά «εγκατάσταση» (ίσως χρειάζεται expand) και η
    ...                είσοδος γίνεται με κουμπί «Είσοδος στην εταιρεία …».
    [Arguments]    ${companyTIN1}
    Go To    ${CO_SELECT_URL}
    Wait For Page Ready
    # Τρέχον UI (Οκτ 2026): 2 επίπεδα. ΑΡΙΣΤΕΡΑ λίστα «Εγκαταστάσεων»
    # (<button class="…min-h-12…"> με κείμενο «<όνομα> <πλήθος>»), ΔΕΞΙΑ οι
    # εταιρείες της επιλεγμένης εγκατάστασης (κάρτα με «ΑΦΜ: …» + κουμπί
    # aria-label="Είσοδος στην εταιρεία <όνομα>").
    # 1) Αναζήτηση με ΑΦΜ -> φιλτράρει τις εγκαταστάσεις αριστερά.
    Safe Input Text    ${CO_SEARCH_INPUT}    ${companyTIN1}    timeout=25s
    # 2) Κλικ στην (φιλτραρισμένη) εγκατάσταση αριστερά για να φορτώσουν οι εταιρείες της.
    Safe Click    xpath=(//button[contains(@class,'min-h-12')])[1]
    # 3) Κλικ «Είσοδος» στην κάρτα της εταιρείας που εμφανίζει το συγκεκριμένο ΑΦΜ.
    ${enter}=    Set Variable
    ...    xpath=//li[.//*[contains(normalize-space(.),'${companyTIN1}')]]//button[contains(@aria-label,'Είσοδος στην εταιρεία')]
    Wait Until Element Is Visible    ${enter}    12s
    Safe Click    ${enter}
    Wait Until Keyword Succeeds    4x    3s    Land On Company Home

# ======================================
# ----------- USER CONTROL -----------
# ======================================
Navigate To User Management

    Expand Menu By Text    Διαχείριση
    Click Menu Item By Name    Διαχείριση Χρηστών
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage

Delete User
    [Arguments]    ${name}=${newUserName}
    Safe Click    xpath=//div[@data-slot='card'][.//span[normalize-space(.)='${name}']]//button[@data-slot='alert-dialog-trigger' and @data-variant='destructive']    timeout=10s
    Safe Click    xpath=//button[@data-slot='alert-dialog-action' and contains(., 'Διαγραφή')]
    # Περιμένουμε πρώτα το success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']    timeout=20s

    # Reload της σελίδας για να ανανεωθεί η λίστα
    Reload Page
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage    20s

    # Τώρα ελέγχουμε ότι ο χρήστης δεν υπάρχει
    Wait Until Element Is Not Visible    xpath=//div[@data-slot='card'][.//span[normalize-space(.)='${name}']]    timeout=15s

Add Admin User
    [Arguments]    ${name}=${newUserName}    ${email}=${newUserEmail}

    Safe Click    xpath=//button[@data-slot='sheet-trigger' and contains(., 'Προσθήκη')]
    Wait Until Page Contains    Προσθήκη Χρήστη    10s
    Safe Input Text    id=email    ${email}
    Safe Wait Element      id=check-0    timeout=10s

    ${checked}=    Get Element Attribute    id=check-0    aria-checked
    Run Keyword If    '${checked}' == 'false'    Click Element    id=check-0

    # Κλικ Αποθήκευση αλλαγών
    Safe Click                    xpath=//button[@type='submit' and contains(., 'Αποθήκευση αλλαγών')]

    # Επαλήθευση success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']//div[@data-title and contains(., 'Επιτυχής δημιουργία χρήστη')]    timeout=10s
    # Επαλήθευση ότι ο χρήστης εμφανίζεται στη λίστα με ρόλο Διαχειριστής
    Wait Until Element Is Visible    xpath=//span[contains(text(), '${name}')]    timeout=10s
    Wait Until Element Is Visible    xpath=//span[@data-slot='badge' and contains(., 'Διαχειριστής')]    timeout=15s
# ======================================
# ----------- CHANGE COMPANY -----------
# ======================================

Change Company
    [Documentation]    Αλλάζει την επιλεγμένη εταιρεία μέσω της σελίδας «Επιλογή Εταιρείας»
    ...                (τρέχον UI). Ψάχνει με το όνομα και μπαίνει με «Είσοδος στην εταιρεία …».
    [Arguments]    ${company_name}=${newCompanyName}
    Go To    ${CO_SELECT_URL}
    Wait For Page Ready
    # Τρέχον UI (Οκτ 2026): αναζήτηση -> φιλτράρισμα εγκαταστάσεων αριστερά,
    # κλικ στην εγκατάσταση, μετά «Είσοδος» στη συγκεκριμένη εταιρεία δεξιά.
    Safe Input Text    ${CO_SEARCH_INPUT}    ${company_name}    timeout=25s
    Safe Click    xpath=(//button[contains(@class,'min-h-12')])[1]
    ${enter}=    Set Variable
    ...    xpath=//button[contains(@aria-label,'Είσοδος στην εταιρεία') and contains(@aria-label,'${company_name}')]
    Wait Until Element Is Visible    ${enter}    12s
    Safe Click    ${enter}
    Wait Until Keyword Succeeds    4x    3s    Land On Company Home

Validate Company Changed
    [Documentation]    Επαληθεύει ότι η αλλαγή εταιρείας ολοκληρώθηκε σωστά
    [Arguments]    ${company_name}=${newCompanyName}    ${aade_user}=${expectedAadeUser}

    # 1. Πλοήγηση στη Διαχείριση Εταιρείας
    Safe Click    xpath=//a[@data-slot='sidebar-menu-sub-button' and @href='/company/manage']
    Wait Until Location Is    ${BASE_URL}/company/manage    20s

    # 2. Έλεγχος aadeUsername
    Safe Wait Element    xpath=//input[@name='aadeUsername']
    Wait Until Keyword Succeeds    5x    5s    Validate Aade Username    ${aade_user}

    # 3. Έλεγχος ονόματος εταιρείας στο sidebar
    Wait Until Element Is Visible
    ...    xpath=(//span[@class='truncate font-medium' and normalize-space(.)='${company_name}'])[1]
    ...    timeout=10s

Validate Aade Username
    [Documentation]    Helper για επαλήθευση του aadeUsername input value
    [Arguments]    ${expected_value}
    ${actual_value}=    Get Element Attribute    xpath=//input[@name='aadeUsername']    value
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    msg=Expected aadeUsername to be '${expected_value}' but found '${actual_value}'

# ======================================
# --- DocPilot: COMPANY SWITCH (current UI) ---
# ======================================
Ensure Submenu Open
    [Documentation]    Ανοίγει ένα collapsible μενού ΜΟΝΟ αν το υπο-στοιχείο
    ...                δεν είναι ήδη ορατό (αποφεύγει το toggle-close).
    [Arguments]    ${trigger}    ${item}
    ${vis}=    Run Keyword And Return Status    Element Should Be Visible    ${item}
    IF    not ${vis}
        Safe Click    ${trigger}
        Wait Until Element Is Visible    ${item}    10s
    END

Enter Company
    [Documentation]    Μπαίνει σε συγκεκριμένη εταιρεία. Οι εταιρείες είναι
    ...                ομαδοποιημένες ανά «εγκατάσταση»: αν χρειαστεί, κάνει
    ...                πρώτα expand την εγκατάσταση και μετά «Είσοδος».
    ...                ${installation} = όνομα εγκατάστασης (π.χ. "Greg K")
    ...                ${company} = μέρος του ονόματος εταιρείας στο κουμπί εισόδου.
    [Arguments]    ${installation}    ${company}
    Go To    ${CO_SELECT_URL}
    Wait For Page Ready
    # Τρέχον UI (Οκτ 2026): ΑΡΙΣΤΕΡΑ επιλέγουμε την εγκατάσταση με το όνομα
    # (button class ~min-h-12, κείμενο «<όνομα> <πλήθος εταιρειών>»), ΔΕΞΙΑ
    # φορτώνουν οι εταιρείες της και μπαίνουμε με «Είσοδος στην εταιρεία …».
    Safe Click    xpath=//button[contains(@class,'min-h-12') and contains(normalize-space(.),'${installation}')]
    ${enter}=    Set Variable
    ...    xpath=//button[contains(@aria-label,'Είσοδος στην εταιρεία') and contains(@aria-label,'${company}')]
    Wait Until Element Is Visible    ${enter}    12s
    Safe Click    ${enter}
    # Η αλλαγή εταιρείας μπορεί να μην έχει ολοκληρωθεί όταν κάνουμε Go To, οπότε
    # το home φορτώνει χωρίς πλήρες sidebar. Κάνουμε retry το «μετάβαση + wait sidebar»
    # (παράλληλα παρακάμπτει και τυχόν stale redirectUrl σε παραστατικό άλλης εταιρείας).
    Wait Until Keyword Succeeds    4x    3s    Land On Company Home

Land On Company Home
    Go To    ${urlHotdog}
    Wait Until Element Is Visible    ${NAV_DOCUMENTS}    15s
    Wait For Page Ready

# ======================================
# --- DocPilot: DASHBOARD ---
# ======================================
Verify Dashboard Widgets
    Go To    ${urlHotdog}
    Wait For Page Ready
    Wait Until Page Contains    Εισερχόμενα παραστατικά    15s
    Page Should Contain    Εκδότες
    Page Should Contain    Τύποι παραστατικών

# ======================================
# --- DocPilot: DOCUMENTS / FILTERS ---
# ======================================
Open Documents Page
    Go To    ${DOCS_URL}
    Wait For Page Ready
    # Το κουμπί «Αναζήτηση» είναι disabled μέχρι να μπουν ημ/νίες — περιμένουμε
    # το πεδίο ημερομηνίας (ορατό) αντί για το κουμπί.
    Wait Until Element Is Visible    ${DATE_FROM}    20s

Search Documents With Date Range
    [Arguments]    ${from}=01/01/2024    ${to}=31/12/2026
    Open Documents Page
    Safe Input Text    ${DATE_FROM}    ${from}
    Safe Input Text    ${DATE_TO}      ${to}
    Safe Click    ${SEARCH_BUTTON}
    Wait For Page Ready
    Wait Until Element Is Visible    ${VIEW_LINK_FIRST}    20s

Open First Delivery Note
    [Documentation]    Φιλτράρει Δελτία Διακίνησης και ανοίγει το 1ο σε Προβολή.
    Go To    ${DN_FILTER_URL}
    Wait For Page Ready
    # Η λίστα φορτώνει async — περιμένουμε να εμφανιστεί το «Προβολή» πριν το click.
    Safe Wait Element    ${VIEW_LINK_FIRST}    25s
    Safe Click    ${VIEW_LINK_FIRST}
    Wait Until Location Contains    /invoices/incoming/    15s
    Wait Until Page Contains    Εικόνα παραστατικού    20s

Verify Document View Actions
    [Documentation]    Read-only έλεγχος ότι υπάρχουν τα κουμπιά/σύνδεσμοι προβολής.
    [Tags]    read-only
    Wait Until Element Is Visible    ${VIEW_XML_LINK}    15s
    Page Should Contain Element    ${VIEW_PORTAL_LINK}
    Page Should Contain Element    ${VIEW_MYDATA_LINK}
    Page Should Contain Element    ${VIEW_PRINT_BTN}
    Page Should Contain Element    ${VIEW_ARCHIVE_BTN}

# ======================================
# --- DocPilot: ROLE-SPECIFIC CHECKS ---
# ======================================
Verify Receipt Actions Available
    [Documentation]    WAREHOUSE MANAGER: ανοίγει το μενού ενεργειών παραλαβής σε
    ...                Δελτίο Διακίνησης και επαληθεύει τις 3 επιλογές — ΧΩΡΙΣ να
    ...                εκτελεί καμία (άνοιγμα μενού = μη-αναστρέψιμο, read-only).
    [Tags]    read-only    warehouse-manager
    Open First Delivery Note
    Safe Wait Element    ${RECEIPT_TRIGGER}    15s
    Safe Click    ${RECEIPT_TRIGGER}
    Wait Until Element Is Visible    ${RECEIPT_CONFIRM}    10s
    Page Should Contain Element    ${RECEIPT_PARTIAL}
    Page Should Contain Element    ${RECEIPT_REJECT}
    Press Keys    ${None}    ESCAPE

Verify Receipt Actions Not Available
    [Documentation]    Μη-WM ρόλος: το κουμπί ενεργειών παραλαβής ΔΕΝ υπάρχει.
    Open First Delivery Note
    Page Should Not Contain Element    ${RECEIPT_TRIGGER}

Verify Technical Manager Menu
    Ensure Submenu Open    ${MENU_MANAGEMENT}    ${MGMT_CUSTOM_FIELDS}
    Page Should Contain Element    ${MGMT_API_KEYS}
    Page Should Contain Element    ${MGMT_API_DOCS}

Verify AI Schema Button Appears On Selection
    Open Documents Page
    Safe Click    ${ROW_CHECKBOX_FIRST}
    Wait Until Element Is Visible    ${AI_SCHEMA_BUTTON}    10s

Verify Administrator Menu
    Ensure Submenu Open    ${MENU_MANAGEMENT}    ${MGMT_USERS}
    Page Should Contain Element    ${MGMT_COMPANY}
    Page Should Contain Element    ${MGMT_PACKAGES}
    Ensure Submenu Open    ${MENU_HISTORY}    ${HISTORY_SYNC}

Verify Simple User Menu
    [Documentation]    Simple user: ΜΟΝΟ Αρχική + Παραστατικά (χωρίς Διαχείριση/Ιστορικό).
    Page Should Contain Element    ${NAV_HOME}
    Page Should Contain Element    ${NAV_DOCUMENTS}
    Page Should Not Contain Element    ${MENU_MANAGEMENT}
    Page Should Not Contain Element    ${MENU_HISTORY}

*** Test Cases ***
TC 01 - Login Success
    Valid Login Test    ${userEmail1}    ${pwd1}

TC 02 - Select Company Success
    Select Company    ${companyTIN1}

TC 03 - Delete And Recreate Admin User
    Navigate To User Management
    Delete User    ${newUserName}
    Add Admin User    ${newUserName}    ${newUserEmail}
TC 04 - Change Company
    Change Company    ${newCompanyName}
    Validate Company Changed    ${newCompanyName}    ${expectedAadeUser}

# ======================================
# --- DocPilot feature / role tests ---
# (κάθε role-test μπαίνει πρώτα στη σωστή εταιρεία, ώστε να είναι ανεξάρτητο)
# ======================================
TC 05 - Dashboard Widgets
    [Documentation]    Αρχική: εμφανίζονται τα widgets (Εισερχόμενα, Εκδότες, Τύποι).
    [Tags]    smoke    dashboard
    Enter Company    LMC Demo    LMC Demo
    Verify Dashboard Widgets

TC 06 - Documents Search With Date Range
    [Documentation]    Παραστατικά: φίλτρο ημερομηνιών + Αναζήτηση φέρνει αποτελέσματα.
    [Tags]    smoke    documents
    Search Documents With Date Range    01/01/2024    31/12/2026

TC 07 - Document View Actions (read-only)
    [Documentation]    Προβολή παραστατικού: portal link, MyData QR, XML, Εκτύπωση, Αρχειοθέτηση.
    [Tags]    documents    read-only
    Open First Delivery Note
    Verify Document View Actions

TC 08 - Warehouse Manager Receipt Actions Present
    [Documentation]    LMC Demo (έχει ρόλο Warehouse Manager): εμφανίζονται οι Ενέργειες Παραλαβής
    ...                σε Δελτίο Διακίνησης. (Σημ.: η Παπάκι —ενώ θα έπρεπε WM— στο portal
    ...                εμφανίζεται ως Administrator, οπότε το WM test γίνεται στη LMC.)
    [Tags]    warehouse-manager    read-only
    Enter Company    LMC Demo    LMC Demo
    Verify Receipt Actions Available

TC 09 - Technical Manager Items Visible
    [Documentation]    VDM (Technical Manager): Προσαρμοσμένα Πεδία/Κλειδιά API/Τεκμηρίωση API + AI Schema.
    [Tags]    technical-manager
    Enter Company    VDM    VDM
    Verify Technical Manager Menu
    Verify AI Schema Button Appears On Selection

TC 10 - Administrator Menu Visible & No Receipt Actions
    [Documentation]    Greg K (Administrator): Διαχείριση Χρηστών/Εταιρείας/Πακέτα + Ιστορικό· ΧΩΡΙΣ ενέργειες παραλαβής.
    [Tags]    administrator
    Enter Company    Greg K    Greg K
    Verify Administrator Menu
    Verify Receipt Actions Not Available

TC 11 - Simple User Sees Only Home And Documents
    [Documentation]    PROSVASIS (Simple user, κάτω από εγκατάσταση Greg K): μόνο Αρχική + Παραστατικά.
    [Tags]    simple-user
    Enter Company    Greg K    PROSVASIS
    Verify Simple User Menu