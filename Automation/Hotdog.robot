*** Settings ***
Documentation   Hotdog
Library         SeleniumLibrary
Suite Setup     Open Headless Browser
Suite Teardown  Close Browser Session

*** Variables ***
${urlHotdog}      https://hotdoc.impact.gr/
${Browser1}         Chrome
${HEADLESS}         False    # Τοπικά False, στο GitHub True
${userEmail1}     gregkazakou@gmail.com
${pwd1}           Papaki2!
${companyTIN1}    135952929
${newUserName}      Grigoris Kazakou
${newUserEmail}     gkazakou@impact.gr
${INVALID_EMAIL}    mhtsos@something.com

${LOGIN_LINK}    xpath=//a[@href="/auth/login"]
${SEARCH_INPUT}    xpath=//input[@placeholder="Αναζήτηση εταιρίας μέσω ΑΦΜ"]
${SUCCESS_LOGIN_URL}    https://hotdoc.impact.gr/company/select?redirectUrl=%2F

${USERNAME_FIELD}    id=emailInput
${PASSWORD_FIELD}    name=LoginInput.Password
${LOGIN_BUTTON}      id=loginButton
${LOGIN_URL}    https://hotdoc.impact.gr/auth/login
${newCompanyName}      LMC Demo
${expectedAadeUser}    LMCNEW2025
${BASE_URL}             https://hotdoc.impact.gr

*** Keywords ***
# ======================================
# ---------------- HELPERS -------------
# ======================================
Safe Click
    [Arguments]    ${locator}    ${timeout}=10s

    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Run Keywords
    ...    Scroll Element Into View    ${locator}
    ...    AND    Element Should Be Visible    ${locator}
    ...    AND    Element Should Be Enabled    ${locator}
    ...    AND    Click Element    ${locator}

Safe Wait Element
    [Arguments]    ${locator}    ${timeout}=10s

    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Run Keywords
    ...    Scroll Element Into View    ${locator}
    ...    AND    Element Should Be Visible    ${locator}
    ...    AND    Element Should Be Enabled    ${locator}

Safe Input Text
    [Arguments]    ${locator}    ${text}    ${timeout}=10s

    Safe Wait Element    ${locator}    ${timeout}
    Clear Element Text   ${locator}
    Input Text           ${locator}    ${text}

Wait For Page Ready
    # Basic “page loaded” check
    Wait Until Page Contains Element    xpath=//body    10s

Expand Menu By Text
    [Arguments]    ${menu_name}

    ${MENU}    Set Variable    xpath=//button[.//span[normalize-space(.)="${menu_name}"]]
    Safe Wait Element    ${MENU}
    ${expanded}=    Get Element Attribute    ${MENU}    aria-expanded
    Run Keyword If    '${expanded}' == 'false'
    ...    Safe Click    ${MENU}

Click Menu Item By Name
    [Arguments]    ${item_name}
    Wait Until Element Is Visible    xpath=//a[normalize-space()="${item_name}"]
    Click Element    xpath=//a[normalize-space()="${item_name}"]
# ======================================
# ---------------- SUITE -------------
# ======================================

Open Headless Browser
    IF    '${HEADLESS}' == 'True'
        Open Browser    ${urlHotdog}    ${Browser1}    options=add_argument("--headless")
    ELSE
        Open Browser    ${urlHotdog}    ${Browser1}
    END
    Maximize Browser Window
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
    Wait Until Location Is    ${SUCCESS_LOGIN_URL}    30s

# ======================================
# ----------- COMPANY SELECT -----------
# ======================================

Select Company
    [Arguments]    ${companyTIN1}
    Safe Input Text    ${SEARCH_INPUT}    ${companyTIN1}    timeout=25s
    Safe Click    xpath=//button[.//span[normalize-space(.)="Επιλογή"]]
    Wait Until Page Contains    επιλέχθηκε    15s
    Wait Until Location Is    https://hotdoc.impact.gr/    20s
    Wait Until Page Contains    επιλέχθηκε    15s
    ${text}=    Get Text    xpath=//*[contains(., "επιλέχθηκε")]
    Should Match Regexp    ${text}    Η εταιρεία.+επιλέχθηκε

# ======================================
# ----------- USER CONTROL -----------
# ======================================
Navigate To User Management

    Expand Menu By Text    Διαχείριση
    Click Menu Item By Name    Διαχείριση Χρηστών
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage

Delete User
    [Arguments]    ${name}=${newUserName}
    Safe Click     xpath=//span[contains(text(), '${name}')]/ancestor::div[contains(@class,'flex')]//button[@data-slot='alert-dialog-trigger']    timeout=10s
    Safe Click    xpath=//button[@data-slot='alert-dialog-action' and contains(., 'Διαγραφή')]
    # Περιμένουμε πρώτα το success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']    timeout=20s

    # Reload της σελίδας για να ανανεωθεί η λίστα
    Reload Page
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage    20s

    # Τώρα ελέγχουμε ότι ο χρήστης δεν υπάρχει
    Wait Until Element Is Not Visible    xpath=//span[contains(text(), '${name}')]    timeout=15s

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
    [Documentation]    Αλλάζει την επιλεγμένη εταιρεία μέσω του sidebar dropdown
    [Arguments]    ${company_name}=${newCompanyName}

    # 1. Άνοιγμα του dropdown επιλογής εταιρείας στο sidebar
    Safe Click    xpath=//button[@data-slot='dropdown-menu-trigger' and @data-sidebar='menu-button']

    # 2. Περιμένουμε το menu content να γίνει visible (κρίσιμο για stability)
    Wait Until Element Is Visible
    ...    xpath=//div[@data-slot='dropdown-menu-content' and @data-state='open']
    ...    timeout=10s

    # 3. Επιλογή της εταιρείας — ψάχνουμε ΜΟΝΟ τα text nodes του menuitem
    #    ώστε να αγνοήσουμε το avatar div με τα αρχικά (π.χ. "LD", "ΠΑ")
    Safe Click
    ...    xpath=//div[@data-slot='dropdown-menu-content' and @data-state='open']//div[@role='menuitem' and normalize-space(text()[normalize-space()])='${company_name}']

    # 4. Επαλήθευση toast μηνύματος
    Wait Until Element Is Visible
    ...    xpath=//li[@data-sonner-toast]//div[@data-title and contains(., 'Η εταιρεία ${company_name} επιλέχθηκε')]
    ...    timeout=10s

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