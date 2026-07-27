"""
NotificationPayloads.py
Robot Framework library που φτιάχνει τα payloads για τα σενάρια ειδοποιήσεων.

Κάθε endpoint έχει ΔΙΑΦΟΡΕΤΙΚΟ schema στο AdditionalDetails. Η βιβλιοθήκη
γνωρίζει αυτές τις διαφορές και τις εφαρμόζει, αντί να στέλνει το ίδιο μπλοκ
παντού (που θα αγνοούνταν σιωπηλά).

Schema ανά endpoint
-------------------
b2b_json / b2g_json : camelCase, πλήρες (method, emails, delay, cells, pdf) -> ΟΛΑ τα σενάρια
deliverynote        : camelCase, ΧΩΡΙΣ notificationDelay στο αρχικό template   -> προστίθεται (ΑΕΠΙΒΕΒΑΙΩΤΟ)
jsonxml             : PascalCase, ΧΩΡΙΣ CustomerCellNumbers/NotificationDelay  -> προστίθενται (ΑΝΕΠΙΒΕΒΑΙΩΤΑ)
grcore              : flat positional 'A$' record -> μόνο email + method είναι γνωστές θέσεις
cancel_dn           : μόνο vat/mark/notificationEmails -> το matrix δεν εφαρμόζεται
"""

import copy
import json
import os
import re
from datetime import datetime, timedelta

from robot.api import logger
from robot.api.deco import keyword, library

TEMPLATE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates")

# Endpoints που ΔΕΝ υποστηρίζουν εγγενώς όλα τα πεδία του matrix.
SCHEMA_CAVEATS = {
    "deliverynote": ["notificationDelay"],
    "jsonxml": ["CustomerCellNumbers", "NotificationDelay"],
}

ENDPOINT_PATHS = {
    "b2b_json": "invoice/json",
    "b2g_json": "invoice/json",
    "jsonxml": "invoice/json",
    "deliverynote": "invoice/json",
    "grcore": "invoice/grcore",
    "cancel_dn": "Invoice/cancelDeliveryNote",
}

TEMPLATE_FILES = {
    "b2b_json": "b2b_json.json",
    "b2g_json": "b2g_json.json",
    "jsonxml": "jsonxml.json",
    "deliverynote": "deliverynote.json",
    "grcore": "grcore.txt",
    "cancel_dn": "cancel_dn.json",
}


@library(scope="GLOBAL")
class NotificationPayloads:
    """Χτίζει payloads ανά endpoint και σενάριο ειδοποίησης."""

    ROBOT_LIBRARY_VERSION = "1.0"

    def __init__(self):
        self._counter = 0
        self._cfg = {}
        self._templates = {}
        self._document_mark = ""

    # ------------------------------------------------------------------ setup

    @keyword("Configure Payload Data")
    def configure_payload_data(
        self,
        issuer_tin,
        counterparty_tin,
        valid_email,
        invalid_email,
        valid_cell,
        invalid_cell,
        invoice_number_seed=1,
    ):
        """Ορίζει τις τιμές που θα μπουν στη θέση των {{placeholders}}."""
        self._cfg = {
            "issuerTIN": str(issuer_tin),
            "counterPartyTIN": str(counterparty_tin),
            "validEmailAddress": str(valid_email),
            "invalidEmailAddress": str(invalid_email),
            "validCellphoneNumber": str(valid_cell),
            "invalidCellphoneNumber": str(invalid_cell),
        }
        self._counter = int(invoice_number_seed)
        logger.info("Payload data configured. invoiceNumber seed=%s" % self._counter)

    # -------------------------------------------------------------- templates

    def _load_template(self, endpoint):
        if endpoint not in TEMPLATE_FILES:
            raise ValueError(
                "Άγνωστο endpoint '%s'. Έγκυρα: %s"
                % (endpoint, ", ".join(sorted(TEMPLATE_FILES)))
            )
        if endpoint not in self._templates:
            path = os.path.join(TEMPLATE_DIR, TEMPLATE_FILES[endpoint])
            with open(path, encoding="utf-8") as fh:
                self._templates[endpoint] = fh.read()
        return self._templates[endpoint]

    def _substitute(self, raw):
        """Αντικαθιστά τα {{placeholders}} του Postman με πραγματικές τιμές."""
        self._counter += 1
        now = datetime.now()
        values = dict(self._cfg)
        values["invoiceNumber"] = str(self._counter)
        values["currentDateTime"] = now.strftime("%Y-%m-%dT%H:%M:%S")
        values["currentDate"] = now.strftime("%Y-%m-%d")
        values["documentMARK"] = self._document_mark
        # defaults ώστε να μη μείνει ποτέ αναντικατάστατο placeholder
        values.setdefault("TransmissionMethod", "A")
        values.setdefault("DelayMinutes", "0")
        values.setdefault("InvoiceAttach", "false")

        def repl(match):
            key = match.group(1)
            if key not in values:
                raise ValueError("Δεν βρέθηκε τιμή για το placeholder {{%s}}" % key)
            return values[key]

        return re.sub(r"\{\{(\w+)\}\}", repl, raw)

    # ------------------------------------------------------- payload building

    def _emails(self, include):
        if not include:
            return None
        return [self._cfg["validEmailAddress"], self._cfg["invalidEmailAddress"]]

    def _cells(self, include):
        if not include:
            return None
        return [self._cfg["validCellphoneNumber"], self._cfg["invalidCellphoneNumber"]]

    @keyword("Build Notification Payload")
    def build_notification_payload(
        self,
        endpoint,
        method="A",
        accounting_emails=True,
        customer_cells=False,
        send_as_pdf=False,
        pdf_emails=True,
        notification_delay=0,
    ):
        """Επιστρέφει το body για το δοσμένο endpoint/σενάριο.

        Για JSON endpoints επιστρέφει dict. Για grcore επιστρέφει string.
        """
        raw = self._substitute(self._load_template(endpoint))

        if endpoint == "grcore":
            # Flat positional format: ΜΟΝΟ το TransmissionMethod slot είναι γνωστό.
            logger.warn(
                "GRCORE: μόνο TransmissionMethod μεταβάλλεται. Οι θέσεις για cells/"
                "sendAsPdf/pdfEmails/delay στο 'A$' record είναι άγνωστες και ΔΕΝ "
                "τροποποιούνται."
            )
            return raw

        body = json.loads(raw)

        if endpoint == "cancel_dn":
            body["notificationEmails"] = self._emails(accounting_emails)
            return body

        delay = int(notification_delay)

        if endpoint == "jsonxml":
            # PascalCase + μειωμένο schema
            body["AdditionalDetails"] = {
                "AccountingDepartmentEmails": self._emails(accounting_emails),
                "TransmissionMethod": method,
                "SendAsPdf": bool(send_as_pdf),
                "AvoidEmailGrouping": False,
                "PdfNotificationEmails": self._emails(pdf_emails),
                # --- πεδία εκτός αρχικού schema ---
                "CustomerCellNumbers": self._cells(customer_cells),
                "NotificationDelay": delay,
            }
        else:
            template_name = (
                "defualt_deliverynote" if endpoint == "deliverynote" else "DefualtTemplate"
            )
            tags = ["API-TEST", method, "Delay%d" % delay]
            if send_as_pdf:
                tags.append("PDF")
            body["AdditionalDetails"] = {
                "TransmissionMethod": method,
                "accountingDepartmentEmails": self._emails(accounting_emails),
                "documentTemplate": template_name,
                "notificationDelay": delay,
                "customerCellNumbers": self._cells(customer_cells),
                "sendAsPdf": bool(send_as_pdf),
                "pdfNotificationEmails": self._emails(pdf_emails),
                "DocumentTags": tags,
            }

        for field in SCHEMA_CAVEATS.get(endpoint, []):
            logger.warn(
                "SCHEMA CAVEAT [%s]: το πεδίο '%s' ΔΕΝ υπάρχει στο αρχικό template. "
                "Αν το endpoint το αγνοήσει ή το απορρίψει, αυτό είναι το εύρημα."
                % (endpoint, field)
            )

        return body

    @keyword("Set Document Mark")
    def set_document_mark(self, mark):
        """Αποθηκεύει το mark προηγούμενης υποβολής (χρειάζεται για το cancel)."""
        self._document_mark = str(mark)

    @keyword("Get Endpoint Path")
    def get_endpoint_path(self, endpoint):
        """Επιστρέφει το relative path του endpoint."""
        if endpoint not in ENDPOINT_PATHS:
            raise ValueError("Άγνωστο endpoint '%s'" % endpoint)
        return ENDPOINT_PATHS[endpoint]

    @keyword("Get Schema Caveats")
    def get_schema_caveats(self, endpoint):
        """Λίστα πεδίων που προστέθηκαν εκτός του αρχικού schema (κενή αν κανένα)."""
        return SCHEMA_CAVEATS.get(endpoint, [])

    @keyword("Describe Expected Notification")
    def describe_expected_notification(
        self, method, accounting_emails, customer_cells, send_as_pdf, pdf_emails
    ):
        """Περιγράφει τι ΠΡΕΠΕΙ να παραδοθεί - για χειροκίνητη επαλήθευση."""
        expect = []
        if method in ("A", "E", "C") and accounting_emails:
            expect.append("email -> %s (το invalid ΠΡΕΠΕΙ να απορριφθεί/αγνοηθεί)"
                          % self._cfg["validEmailAddress"])
        if method in ("M", "C") and customer_cells:
            expect.append("SMS -> %s (το invalid ΠΡΕΠΕΙ να απορριφθεί/αγνοηθεί)"
                          % self._cfg["validCellphoneNumber"])
        if send_as_pdf and pdf_emails:
            expect.append("PDF συνημμένο -> %s" % self._cfg["validEmailAddress"])
        if not expect:
            expect.append("καμία ειδοποίηση")
        return " | ".join(expect)
