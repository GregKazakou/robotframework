# config/credentials.example.py
# Template — copy this to credentials.py and fill in real values.
# ALL suite variables live here: the .robot files contain NO hardcoded
# credentials, TINs, URLs or accounts.

EINVOICE_API_KEY = "your-api-key-here"
ISSUER_VAT = "EL000000000"

# --- Base URLs ---
UAT_API         = "https://einvoiceapiuat.impact.gr"
MYDATA_API_DEV  = "https://mydataapidev.aade.gr"

# --- Issuer / Transporter ---
ISSUER_TIN                      = "000000000"
AADE_USER_ID_ISSUER             = "your-aade-user-id"
SUBSCRIPTION_KEY_ISSUER         = "your-subscription-key"
TRANSPORTER_TIN                 = "000000000"
AADE_USER_ID_TRANSPORTER        = "your-transporter-aade-user-id"
SUBSCRIPTION_KEY_TRANSPORTER    = "your-transporter-subscription-key"

# --- Recipient (DN Life Cycle.robot) ---
UAT_API_KEY_RECIPIENT       = "your-recipient-provider-api-key"
RECIPIENT_TIN               = "000000000"
AADE_USER_ID_RECIPIENT      = "your-recipient-aade-user-id"
SUBSCRIPTION_KEY_RECIPIENT  = "your-recipient-subscription-key"

# --- E-invoicing Notifications suite (einvoicing_notifications.robot) ---
API_KEY             = EINVOICE_API_KEY
COUNTERPARTY_TIN    = "000000000"
VALID_EMAIL         = "you@example.com"
INVALID_EMAIL       = "invalid-email-address"
VALID_CELL          = "+300000000000"
INVALID_CELL        = "12345"
INVOICE_SEED        = "1"

# --- Hotdog UI suite (Hotdog.robot) ---
HOTDOG_USER_EMAIL          = "your-hotdog-login@example.com"
HOTDOG_PASSWORD            = "your-hotdog-password"
HOTDOG_COMPANY_TIN         = "000000000"
HOTDOG_NEW_USER_NAME       = "Firstname Lastname"
HOTDOG_NEW_USER_EMAIL      = "new-user@example.com"
HOTDOG_COMPANY_NAME        = "Company Demo"
HOTDOG_EXPECTED_AADE_USER  = "AADE-USER"

# --- Runtime variables (populated by tests at execution time) ---
QR_URL                  = ""
PROVIDER_QR_URL         = ""
DELIVERY_NOTE_MARK      = ""
TRANSPORT_MARK          = ""
REJECT_MARK             = ""
GROUP_QR_ID             = ""
INCREMENTAL_COUNTER     = "1"
