# config/credentials.example.py
# Template — copy this to credentials.py and fill in real values.

EINVOICE_API_KEY = "your-api-key-here"
ISSUER_VAT = "EL000000000"

# --- Delivery Note lifecycle (DN Life Cycle.robot) ---
# Required. The issuer/transporter provider key is EINVOICE_API_KEY above.
UAT_API_KEY_RECIPIENT = "your-recipient-provider-api-key"

# AADE myDATA dev credentials (aade-user-id + ocp-apim-subscription-key) per role.
AADE_USER_ID_ISSUER = "your-aade-user-id"
SUBSCRIPTION_KEY_ISSUER = "your-subscription-key"
AADE_USER_ID_RECIPIENT = "your-recipient-aade-user-id"
SUBSCRIPTION_KEY_RECIPIENT = "your-recipient-subscription-key"
AADE_USER_ID_TRANSPORTER = "your-transporter-aade-user-id"
SUBSCRIPTION_KEY_TRANSPORTER = "your-transporter-subscription-key"

# Optional — only if you need to override the defaults hardcoded in the suite.
# DN_ISSUER_TIN = "154697391"
# DN_RECIPIENT_TIN = "135952929"
# DN_TRANSPORTER_TIN = "118058830"
# DN_CARRIER_VAT = "118058830"