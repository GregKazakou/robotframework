*** Test Cases ***
TC 01 - signpos then 11.1 with payment details then validate
    [Tags]    flow_1    signpos    invoice    validate
    Begin Case    F1
    ${idn}=    Next Identifier

    # Step 1 - signpos for 11.1
    ${signpos_payload}=    Build Signpos Payload    11.1    ${idn}    ${0}    ${AMOUNT_TOTAL}
    ${signpos}=    Send And Verify    step1 signpos for 11.1    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 2 - 11.1 invoice with payment details from signpos
    @{empty_marks}=    Create List
    ${invoice_payload}=    Build Invoice 11 Payload    ${idn}    ${signpos.signature}    ${signpos.input}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${invoice}=    Send And Verify    step2 invoice 11.1 with signpos payment    ${EP_INVOICE}    ${invoice_payload}    201
    ...    require=mark

    # Step 3 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}

TC 02 - signpos then 8.4 receipt then validate then 11.1 connected to 8.4
    [Tags]    flow_2    signpos    receipt    invoice    validate
    Begin Case    F2
    ${idn}=    Next Identifier

    # Step 1 - signpos for 8.4
    ${signpos_payload}=    Build Signpos Payload    8.4    ${idn}    ${0}    ${AMOUNT_TOTAL}
    ${signpos}=    Send And Verify    step1 signpos for 8.4    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 2 - 8.4 receipt with cardlines populated from signpos
    @{empty_marks}=    Create List
    ${receipt_payload}=    Build Receipt 8 Payload    ${idn}    ${signpos.signature}    ${signpos.input}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${receipt}=    Send And Verify    step2 receipt 8.4 with signpos cardlines    ${EP_RECEIPT}    ${receipt_payload}    201
    ...    require=mark

    # Step 3 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}

    # Step 4 - 11.1 connected to the 8.4 mark
    @{connected}=    Create List    ${receipt.mark}
    ${invoice_payload}=    Build Invoice 11 Payload    ${idn}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${connected}
    Send And Verify    step4 invoice 11.1 connected to 8.4    ${EP_INVOICE}    ${invoice_payload}    201
    ...    require=mark

TC 03 - 11.1 then signpos with mark then updatePayment then validate
    [Tags]    flow_3    invoice    signpos    update_payment    validate
    Begin Case    F3
    ${idn}=    Next Identifier

    # Step 1 - 11.1 first (no payment yet)
    @{empty_marks}=    Create List
    ${invoice_payload}=    Build Invoice 11 Payload    ${idn}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${invoice}=    Send And Verify    step1 invoice 11.1 plain    ${EP_INVOICE}    ${invoice_payload}    201
    ...    require=mark

    # Step 2 - signpos using mark from 11.1
    ${signpos_payload}=    Build Signpos Payload    11.1    ${idn}    ${invoice.mark}    ${AMOUNT_TOTAL}
    ${signpos}=    Send And Verify    step2 signpos for 11.1 mark    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 3 - updatePayment with mark of 11.1, amounts of 11.1, payment from signpos
    ${upd_payload}=    Build Update Payment Payload    ${invoice.mark}    ${AMOUNT_TOTAL}    ${signpos.signature}    ${signpos.input}
    Send And Verify    step3 updatePayment for 11.1    ${EP_UPDATE_PAYMENT}    ${upd_payload}    200

    # Step 4 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}

TC 04 - 8.4 then signpos with mark then updatePayment then validate
    [Tags]    flow_4    receipt    signpos    update_payment    validate
    Begin Case    F4
    ${idn}=    Next Identifier

    # Step 1 - 8.4 receipt first (cardlines without signpos signature)
    @{empty_marks}=    Create List
    ${receipt_payload}=    Build Receipt 8 Payload    ${idn}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${receipt}=    Send And Verify    step1 receipt 8.4 plain    ${EP_RECEIPT}    ${receipt_payload}    201
    ...    require=mark

    # Step 2 - signpos using mark from 8.4
    ${signpos_payload}=    Build Signpos Payload    8.4    ${idn}    ${receipt.mark}    ${AMOUNT_TOTAL}
    ${signpos}=    Send And Verify    step2 signpos for 8.4 mark    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 3 - updatePayment for the 8.4
    ${upd_payload}=    Build Update Payment Payload    ${receipt.mark}    ${AMOUNT_TOTAL}    ${signpos.signature}    ${signpos.input}
    Send And Verify    step3 updatePayment for 8.4    ${EP_UPDATE_PAYMENT}    ${upd_payload}    400

    # Step 4 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}

TC 05 - Two 11.1 then signpos 8.4 then 8.4 receipt connected to both then validate
    [Tags]    flow_5    invoice    signpos    receipt    validate
    Begin Case    F5
    ${idn_a}=    Next Identifier
    ${idn_b}=    Next Identifier
    ${idn_pos}=  Next Identifier
    ${total_sum}=    Evaluate    ${AMOUNT_TOTAL} * 2

    # Step 1 - first 11.1
    @{empty_marks}=    Create List
    ${inv_a_payload}=    Build Invoice 11 Payload    ${idn_a}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${inv_a}=    Send And Verify    step1 invoice 11.1 first    ${EP_INVOICE}    ${inv_a_payload}    201
    ...    require=mark

    # Step 2 - second 11.1
    ${inv_b_payload}=    Build Invoice 11 Payload    ${idn_b}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${empty_marks}
    ${inv_b}=    Send And Verify    step2 invoice 11.1 second    ${EP_INVOICE}    ${inv_b_payload}    201
    ...    require=mark

    # Step 3 - signpos with invoiceTypeCode 8.4 covering the combined amount
    ${signpos_payload}=    Build Signpos Payload    8.4    ${idn_pos}    ${0}    ${total_sum}
    ${signpos}=    Send And Verify    step3 signpos 8.4 sum    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 4 - 8.4 receipt with signpos payment details and connected to both 11.1s
    @{connected}=    Create List    ${inv_a.mark}    ${inv_b.mark}
    ${receipt_payload}=    Build Receipt 8 Payload    ${idn_pos}    ${signpos.signature}    ${signpos.input}    ${total_sum}    ${connected}
    Send And Verify    step4 receipt 8.4 connected    ${EP_RECEIPT}    ${receipt_payload}    201
    ...    require=mark

    # Step 5 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}

TC 06 - signpos 8.4 then 8.4 receipt then two 11.1 each connected to the 8.4 mark
    [Documentation]    Αντίστροφη ροή του TC 05: πρώτα δημιουργείται το 8.4 με
    ...                τα στοιχεία POS (signpos), και ΜΕΤΑ δύο 11.1 που το
    ...                καθένα συσχετίζεται με το mark του 8.4 μέσω του
    ...                multipleConnectedMarks. Το ποσό του 8.4 ισούται με το
    ...                άθροισμα των δύο 11.1 (total_sum = 2 x AMOUNT_TOTAL).
    [Tags]    flow_6    signpos    receipt    invoice    validate
    Begin Case    F6
    ${idn_pos}=  Next Identifier
    ${idn_a}=    Next Identifier
    ${idn_b}=    Next Identifier
    ${total_sum}=    Evaluate    ${AMOUNT_TOTAL} * 2

    # Step 1 - signpos with invoiceTypeCode 8.4 covering the combined amount
    ${signpos_payload}=    Build Signpos Payload    8.4    ${idn_pos}    ${0}    ${total_sum}
    ${signpos}=    Send And Verify    step1 signpos 8.4 sum    ${EP_SIGNPOS}    ${signpos_payload}    200
    ...    require=signature,input

    # Step 2 - 8.4 receipt with signpos payment details (no connected marks yet)
    @{empty_marks}=    Create List
    ${receipt_payload}=    Build Receipt 8 Payload    ${idn_pos}    ${signpos.signature}    ${signpos.input}    ${total_sum}    ${empty_marks}
    ${receipt}=    Send And Verify    step2 receipt 8.4 with signpos    ${EP_RECEIPT}    ${receipt_payload}    201
    ...    require=mark

    # Step 3 - first 11.1 connected to the 8.4 mark
    @{connected}=    Create List    ${receipt.mark}
    ${inv_a_payload}=    Build Invoice 11 Payload    ${idn_a}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${connected}
    ${inv_a}=    Send And Verify    step3 invoice 11.1 #A connected to 8.4    ${EP_INVOICE}    ${inv_a_payload}    201
    ...    require=mark

    # Step 4 - second 11.1 connected to the same 8.4 mark
    ${inv_b_payload}=    Build Invoice 11 Payload    ${idn_b}    ${EMPTY}    ${EMPTY}    ${AMOUNT_TOTAL}    ${connected}
    ${inv_b}=    Send And Verify    step4 invoice 11.1 #B connected to 8.4    ${EP_INVOICE}    ${inv_b_payload}    201
    ...    require=mark

    # Step 5 - validate
    Validate Signpos    ${signpos.input}    ${signpos.signature}


*** Settings ***
Documentation     Multi-step API flow tests for the einvoice UAT environment.
...
...               Each test wires together /PosTransactions/signpos,
...               /Invoice/json, /Receipt, /PosTransactions/validate and
...               /Invoice/updatePayment, threading mark / signature / input
...               from one response into the next request.
...
...               Flow 1: signpos -> 11.1 (with signpos payment details) -> validate
...               Flow 2: signpos -> 8.4 receipt (cardlines from signpos) -> validate
...                       -> 11.1 with multipleConnectedMarks containing 8.4 mark
...               Flow 3: 11.1 -> signpos for that mark -> updatePayment -> validate
...               Flow 4: 8.4 receipt -> signpos for that mark -> updatePayment -> validate
...               Flow 5: 11.1 (x2) -> signpos with invoiceTypeCode 8.4 (sum amount)
...                       -> 8.4 receipt with signpos payment and the two 11.1 marks
...                          in multipleConnectedMarks -> validate
...               Flow 6: signpos 8.4 (sum amount) -> 8.4 receipt with signpos
...                       payment -> two 11.1, each with the 8.4 mark in
...                          multipleConnectedMarks -> validate
...                       (reverse of Flow 5; 8.4 amount = 2 x 11.1 amount)

Library           helpers.py    WITH NAME    api
Library           Collections
Library           String
Library           DateTime
Library           OperatingSystem
Variables         ${EXECDIR}/config/credentials.py

Suite Setup       Initialize Suite
Suite Teardown    Finalize Suite


*** Variables ***
${BASE_URL}                    ${UAT_API}
${API_KEY}                     ${EINVOICE_API_KEY}
${ISSUER_VAT_NO_PREFIX}        ${ISSUER_TIN}
${ISSUER_VAT}                  EL${ISSUER_VAT_NO_PREFIX}
${TERMINAL_ID}                 16000198
${RESULTS_CSV}                 ${CURDIR}${/}flow_results.csv

# Endpoints
${EP_SIGNPOS}                  /PosTransactions/signpos
${EP_VALIDATE}                 /PosTransactions/validate
${EP_INVOICE}                  /Invoice/json
${EP_RECEIPT}                  /Receipt
${EP_UPDATE_PAYMENT}           /Invoice/updatePayment

# Default amounts (single-document)
${AMOUNT_TOTAL}                ${124}



*** Keywords ***
Initialize Suite
    api.Configure Client    ${BASE_URL}    ${API_KEY}    ${120}

    ${stamp}=      Get Current Date    result_format=epoch    exclude_millis=${True}
    ${stamp_int}=  Convert To Integer    ${stamp}
    Set Suite Variable    $RUN_STAMP    ${stamp_int}
    Set Suite Variable    $IDENT_COUNTER    ${0}
    ${today}=      Get Current Date    result_format=%Y-%m-%d
    Set Suite Variable    $TODAY    ${today}
    ${time_only}=  Get Current Date    result_format=%H:%M:%S
    Set Suite Variable    $START_TIME    ${time_only}

    @{rows_str}=    Create List
    @{rows_dict}=   Create List
    Set Suite Variable    $RESULT_ROWS_STR     ${rows_str}
    Set Suite Variable    $RESULT_ROWS_DICT    ${rows_dict}

    ${signpos_tpl}=    api.Load Template    signpos
    ${invoice_tpl}=    api.Load Template    invoice_11_1
    ${receipt_tpl}=    api.Load Template    receipt_8_4
    Set Suite Variable    $SIGNPOS_TEMPLATE    ${signpos_tpl}
    Set Suite Variable    $INVOICE_TEMPLATE    ${invoice_tpl}
    Set Suite Variable    $RECEIPT_TEMPLATE    ${receipt_tpl}

    ${border}=     Set Variable    ============================================================================================================
    ${banner}=     Catenate    SEPARATOR=\n
    ...    ${EMPTY}
    ...    ${border}
    ...      einvoice UAT Multi-Step Flows
    ...      Started ${TODAY} ${START_TIME} | RUN_STAMP=${RUN_STAMP} | base=${BASE_URL}
    ...    ${border}
    Log To Console    ${banner}

Finalize Suite
    ${summary}=    api.Render Summary    ${RESULT_ROWS_STR}
    Log To Console    ${summary}
    api.Write Results Csv    ${RESULT_ROWS_DICT}    ${RESULTS_CSV}
    ${tail}=    Catenate    SEPARATOR=\n
    ...    ${EMPTY}
    ...    Detailed CSV: ${RESULTS_CSV}
    Log To Console    ${tail}

Begin Case
    [Arguments]    ${case_id}
    Set Test Variable    $CASE_ID    ${case_id}
    Set Test Variable    $STEP       ${0}

Next Identifier
    [Documentation]    Returns a unique identifier per call within the suite.
    ${new}=    Evaluate    ${IDENT_COUNTER} + 1
    Set Suite Variable    $IDENT_COUNTER    ${new}
    ${ident}=    Set Variable    ${RUN_STAMP}${new}
    RETURN    ${ident}

Send And Verify
    [Documentation]    POST a payload, log a one-line result, continue on failure.
    ...                Returns a Bunch-like object so tests can do ${result.mark}.
    ...
    ...                Ελέγχει και το RESPONSE BODY (όχι μόνο το HTTP status):
    ...                  * σε αναμενόμενο 2xx: έγκυρο JSON + body.success=true
    ...                    (όπου το endpoint επιστρέφει success)
    ...                  * σε αναμενόμενο 4xx: body.success να ΜΗΝ είναι true
    ...                  * ${require}: comma-separated πεδία που πρέπει να
    ...                    υπάρχουν μη-κενά στο body, π.χ. require=mark ή
    ...                    require=signature,input
    ...                Αν το response έχει portal url, μπαίνει clickable στο
    ...                test message του report.
    [Arguments]    ${label}    ${endpoint}    ${payload}    ${expected}    ${query}=${None}    ${erp}=none    ${require}=${EMPTY}
    ${new_step}=   Evaluate    ${STEP} + 1
    Set Test Variable    $STEP    ${new_step}

    ${api_res}=    api.Post To    ${endpoint}    ${payload}    ${erp}    ${query}
    ${actual}=     Set Variable    ${api_res}[status_code]
    ${msg}=        Set Variable    ${api_res}[summary]

    ${row_str}=    api.Format Step Row    ${CASE_ID}    ${STEP}    ${label}    ${expected}    ${actual}    ${msg}    ${endpoint}
    ${row_dict}=   api.Make Row Dict      ${CASE_ID}    ${STEP}    ${label}    ${expected}    ${actual}    ${api_res}    ${endpoint}

    Append To List    ${RESULT_ROWS_STR}     ${row_str}
    Append To List    ${RESULT_ROWS_DICT}    ${row_dict}
    Log To Console    \n${row_str}

    # 1) HTTP status
    Run Keyword And Continue On Failure
    ...    Should Be Equal As Integers    ${actual}    ${expected}
    ...    msg=${CASE_ID} step ${STEP} (${endpoint}): expected ${expected}, got ${actual} | ${msg}

    # 2) Response body (success flag + required fields)
    Run Keyword And Continue On Failure
    ...    Verify Response Body    ${api_res}    ${expected}    ${require}    ${label}    ${endpoint}

    # 3) Portal URL στο test message (αν υπάρχει στο response)
    ${url}=    Set Variable    ${api_res}[url]
    IF    '${url}' != '${EMPTY}'
        Set Test Message    *HTML* <br>step ${STEP} ${label}: <a href="${url}">${url}</a>
        ...    append=${True}
    END

    ${bunch}=    Evaluate    type('R',(object,),$api_res)()    modules=builtins
    RETURN    ${bunch}

Verify Response Body
    [Documentation]    Wrapper του api.Verify Body με πλούσιο μήνυμα αποτυχίας.
    [Arguments]    ${api_res}    ${expected}    ${require}    ${label}    ${endpoint}
    ${note}=    api.Verify Body    ${api_res}    ${expected}    ${require}
    Log    ${CASE_ID} step ${STEP} (${endpoint}) ${label}: ${note}    INFO

Validate Signpos
    [Documentation]    POST /PosTransactions/validate?IssuerTin=...
    [Arguments]    ${input}    ${signature}
    ${payload}=    Create Dictionary    input=${input}    signature=${signature}
    ${q}=          Create Dictionary    IssuerTin=${ISSUER_VAT}
    ${res}=        Send And Verify    validate signpos    ${EP_VALIDATE}    ${payload}    200    ${q}
    RETURN    ${res}

Split Amount Net Vat
    [Documentation]    Σπάει ένα μικτό ποσό σε (net, vat) με ΦΠΑ 13%.
    [Arguments]    ${amount}
    ${vat}=    Evaluate    round(float($amount) - float($amount)/1.13, 2)
    ${net}=    Evaluate    round(float($amount) - $vat, 2)
    RETURN    ${net}    ${vat}

Build Signpos Payload
    [Arguments]    ${invoice_type_code}    ${identifier}    ${mark}    ${amount}
    ${net}    ${vat}=    Split Amount Net Vat    ${amount}
    ${over}=    Create Dictionary
    ...    issueDate=${TODAY}
    ...    invoiceTypeCode=${invoice_type_code}
    ...    identifier=${identifier}
    ...    mark=${mark}
    ...    paymentAmount=${amount}
    ...    totalAmount=${amount}
    ...    totalNetAmount=${net}
    ...    totalVatAmount=${vat}
    ...    terminalId=${TERMINAL_ID}
    ${payload}=    api.Deep Merge    ${SIGNPOS_TEMPLATE}    ${over}
    RETURN    ${payload}

Build Invoice 11 Payload
    [Documentation]    Builds an Invoice/json (11.1) body. If signature/input are
    ...                provided, the first PaymentMethod is filled in. The
    ...                multiple_connected list (always required, may be empty) is
    ...                set to multipleConnectedMarks.
    ...
    ...                ${erp_tag} controls the ERP=... entry in DocumentTags.
    ...                If left empty, it falls back to ${CASE_ID}, so each flow
    ...                auto-tags its invoices with its own scenario id (F1..F5).
    ...                Pass an explicit value to override, e.g.
    ...                "Flow1_signpos_invoice_validate".
    [Arguments]    ${identifier}    ${signature}    ${input}    ${amount}    ${multiple_connected}    ${erp_tag}=${EMPTY}
    IF    '${erp_tag}' == ''
        ${effective_tag}=    Set Variable    ${CASE_ID}
    ELSE
        ${effective_tag}=    Set Variable    ${erp_tag}
    END

    ${net}    ${vat}=    Split Amount Net Vat    ${amount}

    ${pm}=    Create Dictionary
    ...    PaymentMethodType=Credit Card
    ...    PaymentMethodTypeCode=${7}
    ...    Amount=${amount}
    ...    tipAmount=${0}
    ...    transactionId=tr1.AUTOTEST.${identifier}
    ...    providersSignature=${signature}
    ...    posInput=${input}
    ...    terminalId=${TERMINAL_ID}
    ...    remarks=POS Credit Card
    @{payment_methods}=    Create List    ${pm}

    ${PaymentDetails}=    Create Dictionary    exchangeCurrencyRate=${1.0}    PaymentMethods=${payment_methods}
    ${Summaries}=         Create Dictionary    totalAllowances=${0.0}    TotalNetAmount=${net}    TotalVATAmount=${vat}    TotalGrossValue=${amount}
    ${dist}=              Create Dictionary    InternalDocumentId=AutoTest_${identifier}

    @{document_tags}=    Create List    transactionType=POS    invoice=11.1    ERP=${effective_tag}
    ${AdditionalDetails}=    Create Dictionary    DocumentTags=${document_tags}

    ${over}=              Create Dictionary
    ...    number=${identifier}
    ...    dateIssued=${TODAY}
    ...    PaymentDetails=${PaymentDetails}
    ...    multipleConnectedMarks=${multiple_connected}
    ...    Summaries=${Summaries}
    ...    DistributionDetails=${dist}
    ...    AdditionalDetails=${AdditionalDetails}

    ${payload}=    api.Deep Merge    ${INVOICE_TEMPLATE}    ${over}
    RETURN    ${payload}

Build Receipt 8 Payload
    [Documentation]    Builds a /Receipt (8.4) body, populating the first cardline
    ...                with signpos data when signature/input are provided.
    [Arguments]    ${identifier}    ${signature}    ${input}    ${amount}    ${multiple_connected}
    ${cl}=    Create Dictionary
    ...    lineNo=${1}
    ...    amount=${amount}
    ...    amountAC=${0}
    ...    tipAmount=${0}
    ...    tipAmountAC=${0}
    ...    transactionId=tr1.AUTOTEST.${identifier}
    ...    providersSignature=${signature}
    ...    posInput=${input}
    ...    terminalId=${TERMINAL_ID}
    ...    remarks=Credit Card
    ...    isInformative=${False}
    ...    isHidden=${False}
    @{cardlines}=    Create List    ${cl}

    ${over}=    Create Dictionary
    ...    number=${identifier}
    ...    providerSignatureIdentifier=${identifier}
    ...    dateIssued=${TODAY}
    ...    totalAmount=${amount}
    ...    cardlines=${cardlines}
    ...    multipleConnectedMarks=${multiple_connected}
    ...    internalDocumentId=AutoTestReceipt_${identifier}

    ${payload}=    api.Deep Merge    ${RECEIPT_TEMPLATE}    ${over}
    RETURN    ${payload}

Build Update Payment Payload
    [Arguments]    ${mark}    ${amount}    ${signature}    ${input}
    ${pm}=    Create Dictionary
    ...    paymentMethodType=POS
    ...    paymentMethodTypeCode=${7}
    ...    amount=${amount}
    ...    transactionId=tr1.AUTOTEST.${mark}
    ...    providersSignature=${signature}
    ...    posInput=${input}
    ...    terminalId=${TERMINAL_ID}
    @{pm_list}=    Create List    ${pm}
    ${payload}=    Create Dictionary
    ...    mark=${mark}
    ...    entityVatNumber=${ISSUER_VAT}
    ...    paymentMethods=${pm_list}
    RETURN    ${payload}
