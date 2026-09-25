"""
Helpers for the einvoice API test suites.

Exposed Robot keywords (snake_case here -> Title Case in .robot):

  HTTP / config
  -------------
  configure_client(base_url, api_key, timeout)
      One-time setup in Suite Setup.

  post_to(path, payload, erp, query) -> dict
      Generic POST. Returns flat dict with status_code, success, message,
      mark, uid, signature, input, summary, raw_text, body_dict.

  post_receipt(payload, erp) -> dict
      Convenience wrapper for /Receipt (used by test_receipt_api.robot).

  Templates / payloads
  --------------------
  load_template(name) -> dict
      Reads templates/<n>.json next to this file and returns a dict.

  deep_merge(base, overrides) -> dict
      Returns a new dict; overrides are deep-merged into a deep copy of base.

  Reporting (shared by both suites)
  ---------------------------------
  format_step_row(...)
  make_row_dict(...)
  render_summary(rows)
  write_results_csv(rows, path)
"""

import copy
import csv
import json
import os
import re
from typing import Any, Dict, List, Optional

import requests


_TEMPLATES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "templates")

_state: Dict[str, Any] = {
    "base_url": None,
    "api_key": None,
    "session": None,
    "timeout": 120,
}


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #
def configure_client(base_url: str, api_key: str, timeout: int = 120) -> None:
    _state["base_url"] = base_url.rstrip("/")
    _state["api_key"] = api_key
    _state["timeout"] = int(timeout)
    _state["session"] = requests.Session()


def post_to(path: str,
            payload: Dict[str, Any],
            erp: str = "none",
            query: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """Generic POST to {base_url}{path}. Returns flat result dict."""
    if _state["session"] is None:
        raise RuntimeError("Call 'Configure Client' in Suite Setup first.")

    if not path.startswith("/"):
        path = "/" + path
    while "//" in path:
        path = path.replace("//", "/")
    url = _state["base_url"] + path
    headers = {
        "apikey": _state["api_key"],
        "erp": erp,
        "Content-Type": "application/json",
    }
    try:
        resp = _state["session"].post(
            url, json=payload, headers=headers,
            params=query or None, timeout=_state["timeout"],
        )
        result = _parse_response(path, resp, payload)
    except requests.exceptions.Timeout:
        result = _network_error_dict(path, payload, "client-side timeout")
    except requests.RequestException as exc:
        result = _network_error_dict(path, payload, f"network error: {exc}")
    _log_api_call("POST", path, result, payload)
    return result


def _log_api_call(method: str, endpoint: str, result: Dict[str, Any],
                  payload: Dict[str, Any]) -> None:
    """Emit a stable, machine-parseable line into the Robot log so the email
    report can list one summary line per API call. Format:
        [[APICALL]] METHOD|endpoint|status|mark|reqdigest|message
    """
    status = result.get("status_code", "")
    mark = result.get("mark", "") or ""
    msg = (result.get("message") or "").replace("\n", " ").replace("|", "/")
    if len(msg) > 140:
        msg = msg[:139] + "…"
    itc = (payload.get("InvoiceTypeCode") or payload.get("invoiceTypeCode")
           or payload.get("invoiceType") or "")
    series = payload.get("Series") or payload.get("series") or ""
    req = " · ".join(x for x in [f"type {itc}" if itc else "", series] if x)
    line = f"[[APICALL]] {method}|{endpoint}|{status}|{mark}|{req}|{msg}"
    try:
        from robot.api import logger as _robot_logger
        _robot_logger.info(line)
    except Exception:
        pass  # running outside Robot (e.g. unit tests)


def get_to(path: str,
           query: Optional[Dict[str, str]] = None,
           base_url: Optional[str] = None) -> Dict[str, Any]:
    """Generic GET to {base_url or configured base}{path}. Returns the same
    flat result dict as post_to. base_url lets a call target another host
    (e.g. the portal for GetDocuments)."""
    if _state["session"] is None:
        raise RuntimeError("Call 'Configure Client' in Suite Setup first.")
    base = (base_url or _state["base_url"] or "").rstrip("/")
    if not path.startswith("/"):
        path = "/" + path
    url = base + path
    headers = {"apikey": _state["api_key"], "Content-Type": "application/json"}
    try:
        resp = _state["session"].get(
            url, headers=headers, params=query or None, timeout=_state["timeout"],
        )
        result = _parse_response(path, resp, {})
    except requests.exceptions.Timeout:
        result = _network_error_dict(path, {}, "client-side timeout")
    except requests.RequestException as exc:
        result = _network_error_dict(path, {}, f"network error: {exc}")
    _log_api_call("GET", path, result, {})
    return result


def post_receipt(payload: Dict[str, Any], erp: str = "none") -> Dict[str, Any]:
    """Backwards-compat wrapper used by test_receipt_api.robot."""
    return post_to("/Receipt", payload, erp)


def _network_error_dict(path: str, payload: Dict[str, Any],
                        msg: str) -> Dict[str, Any]:
    return {
        "endpoint": path,
        "status_code": 0,
        "success": None,
        "message": msg,
        "mark": "",
        "uid": "",
        "signature": "",
        "input": "",
        "internal_id": payload.get("internalDocumentId", ""),
        "server_series": payload.get("series", ""),
        "url": "",
        "authentication_code": "",
        "summary": msg,
        "raw_text": "",
        "body_dict": {},
    }


def _parse_response(path: str, response: requests.Response,
                    sent_payload: Dict[str, Any]) -> Dict[str, Any]:
    body: Any = {}
    try:
        body = response.json() if response.text else {}
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {"raw": body}

    success = body.get("success")
    message = body.get("message") or ""
    mark = body.get("mark") or ""
    uid = body.get("uid") or body.get("uniqueId") or ""

    signature = (body.get("signature") or body.get("Signature")
                 or _nested(body, ["data", "signature"])
                 or _nested(body, ["result", "signature"]) or "")
    input_field = (body.get("input") or body.get("Input")
                   or _nested(body, ["data", "input"])
                   or _nested(body, ["result", "input"]) or "")

    internal_id_returned = body.get("internalId") or ""
    server_series = body.get("series") or ""
    url = body.get("url") or ""
    authentication_code = body.get("authenticationCode") or ""

    # Collect API error details (400s often carry 'errors' with empty 'message')
    errors = body.get("errors")
    if not message and errors:
        if isinstance(errors, list):
            message = "; ".join(str(e) for e in errors[:3])
        else:
            message = str(errors)

    parts: List[str] = []
    if success is not None:
        parts.append(f"success={success}")
    if message:
        m = message if len(message) <= 120 else message[:117] + "..."
        parts.append(f'msg="{m}"')
    if mark:
        parts.append(f"mark={mark}")
    if uid:
        u = str(uid)
        parts.append(f"uid={u[:24]}{'...' if len(u) > 24 else ''}")
    if signature:
        s = str(signature)
        parts.append(f"sig={s[:18]}{'...' if len(s) > 18 else ''}")

    sent_internal = sent_payload.get("internalDocumentId", "")
    if internal_id_returned and sent_internal and internal_id_returned != sent_internal:
        parts.append(f"server_returned_internalId={internal_id_returned}")

    if not parts:
        if response.text:
            t = response.text.strip().replace("\n", " ")
            parts.append(t[:120] + ("..." if len(t) > 120 else ""))
        else:
            parts.append("(empty body)")

    return {
        "endpoint": path,
        "status_code": response.status_code,
        "success": success,
        "message": message,
        "mark": mark,
        "uid": uid,
        "signature": signature,
        "input": input_field,
        "internal_id": internal_id_returned,
        "server_series": server_series,
        "url": url,
        "authentication_code": authentication_code,
        "summary": " | ".join(parts),
        "raw_text": response.text,
        "body_dict": body,
    }


def _nested(d: Any, path: List[str]) -> Any:
    cur = d
    for k in path:
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return None
    return cur


def verify_body(api: Dict[str, Any], expected_status, require: str = "") -> str:
    """Assert the response BODY is consistent with the expected outcome.

    For expected 2xx/3xx:
      * non-empty body must be valid JSON
      * body.success (when the endpoint returns it) must be true
      * every field named in `require` (comma-separated, e.g. "mark" or
        "signature,input") must be present and non-empty
    For expected 4xx/5xx:
      * body.success (when present) must NOT be true

    Raises AssertionError listing every problem found; returns a short
    "body OK" note otherwise.
    """
    problems: List[str] = []
    expected_i = int(expected_status)
    body = api.get("body_dict") or {}
    raw = (api.get("raw_text") or "").strip()
    success = api.get("success")

    if expected_i < 400:
        if raw and not body:
            problems.append(f"body is not valid JSON: {raw[:100]}")
        if success is not None and success is not True:
            problems.append(
                f'body.success={success} (expected true), msg="{api.get("message", "")}"'
            )
        checked = []
        for field in [f.strip() for f in (require or "").split(",") if f.strip()]:
            checked.append(field)
            value = api.get(field)
            if value is None:
                value = body.get(field)
            if not value:
                problems.append(f"required response field '{field}' is missing/empty")
    else:
        checked = []
        if success is True:
            problems.append("body.success=true although an error response was expected")

    if problems:
        raise AssertionError("response body check failed: " + "; ".join(problems))

    what = "success flag" + (f" + {', '.join(checked)}" if checked else "")
    return f"body OK ({what})"


# --------------------------------------------------------------------------- #
# Templates / payloads
# --------------------------------------------------------------------------- #
def load_template(name: str) -> Dict[str, Any]:
    """Load <name>.json from a few likely locations and return a fresh dict.

    Search order (first match wins):
      0) $EINVOICE_TEMPLATES_DIR/<name>.json   (if env var is set)
      1) the literal `name` if it points to an existing file
      2) <helpers.py dir>/{templates,Data,data,payloads}/<name>.json
      3) <helpers.py dir>/<name>.json
      4) <cwd>/{templates,Data,data,payloads}/<name>.json
      5) <cwd>/<name>.json
      6) one level up from cwd, same subfolders

    This makes the suite work whether the JSON files live in `templates/`,
    `Data/`, the project root, or somewhere reachable from helpers.py.
    Override entirely with the EINVOICE_TEMPLATES_DIR environment variable.
    """
    if name.endswith(".json") and os.path.exists(name):
        with open(name, "r", encoding="utf-8") as f:
            return json.load(f)

    bare = name[:-5] if name.endswith(".json") else name
    helpers_dir = os.path.dirname(os.path.abspath(__file__))
    cwd = os.getcwd()
    parent = os.path.dirname(cwd)
    subfolders = ["templates", "Data", "data", "payloads"]

    candidates: List[str] = []
    env_dir = os.environ.get("EINVOICE_TEMPLATES_DIR")
    if env_dir:
        candidates.append(os.path.join(env_dir, f"{bare}.json"))
    for base in (helpers_dir, cwd, parent):
        for sub in subfolders:
            candidates.append(os.path.join(base, sub, f"{bare}.json"))
        candidates.append(os.path.join(base, f"{bare}.json"))

    for path in candidates:
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)

    tried = "\n   ".join(candidates)
    raise FileNotFoundError(
        f"Template '{bare}.json' not found. Set EINVOICE_TEMPLATES_DIR or "
        f"place the file in one of:\n   {tried}"
    )


def deep_merge(base: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    """Deep-merge `overrides` into a deep copy of `base` and return it."""
    out = copy.deepcopy(base)
    _deep_merge_inplace(out, overrides or {})
    return out


def _series_prefix_from_context(fallback: str) -> str:
    """Build a readable Series prefix from the running Robot test name, e.g.
    test "DN CANCEL - issue a 9.3…" -> "DNCANCEL". Falls back to the caller's
    value outside Robot (e.g. unit tests)."""
    try:
        from robot.libraries.BuiltIn import BuiltIn
        test = BuiltIn().get_variable_value("${TEST NAME}") or ""
    except Exception:
        test = ""
    head = test.split(" - ", 1)[0] if test else ""
    slug = re.sub(r"[^A-Za-z0-9]+", "", head).upper()[:20]
    return slug or (fallback or "EX")


def apply_unique_fields(payload: Dict[str, Any], prefix: str = "EX") -> Dict[str, Any]:
    """Return a copy of `payload` with unique identifiers, so the same example
    JSON can be POSTed repeatedly without duplicate-document rejections.

    The Series is prefixed with a readable tag derived from the current Robot
    test name (so a document's Series shows which case created it); the passed
    `prefix` is only a fallback used outside Robot.

    Only keys that ALREADY exist in the payload are touched (both camelCase
    and PascalCase), so it is safe on any template:
      * Series / series           -> <TESTSLUG>-<timestamp>
      * Number / number / aa       -> <timestamp>
      * dateIssued / DateIssued / issueDate -> today (YYYY-MM-DD)
      * providerSignatureIdentifier / internalDocumentId / InternalDocumentId
        and DistributionDetails.InternalDocumentId -> fresh uuid4
    """
    import datetime
    import uuid

    new = copy.deepcopy(payload)
    now = datetime.datetime.now()
    stamp = now.strftime("%y%m%d%H%M%S") + f"{now.microsecond // 1000:03d}"
    prefix_slug = _series_prefix_from_context(prefix)
    series = f"{prefix_slug}-{stamp}"
    today = now.strftime("%Y-%m-%d")
    guid = str(uuid.uuid4())

    def set_if_present(d: Dict[str, Any], key: str, value: Any) -> None:
        if isinstance(d, dict) and key in d:
            d[key] = value

    for k in ("Series", "series"):
        set_if_present(new, k, series)
    for k in ("Number", "number", "aa"):
        set_if_present(new, k, stamp)
    for k in ("dateIssued", "DateIssued", "issueDate"):
        set_if_present(new, k, today)
    for k in ("providerSignatureIdentifier", "ProviderSignatureIdentifier",
              "internalDocumentId", "InternalDocumentId"):
        set_if_present(new, k, guid)

    dist = new.get("DistributionDetails")
    if isinstance(dist, dict):
        if "InternalDocumentId" in dist:
            dist["InternalDocumentId"] = guid
        # Delivery notes carry dispatch date/time that "age" and get rejected
        # (error 280: DispatchDate must be ≥ current date). Refresh to now.
        iso_now = now.strftime("%Y-%m-%dT%H:%M:%S")
        for k in ("dispatchDate", "dispatchtime", "DispatchDate", "DispatchTime"):
            if k in dist:
                dist[k] = iso_now

    # Tag the document with the running test's slug (a DocumentTag related to
    # the test), so it's easy to spot which case created it. Only for document
    # payloads that carry AdditionalDetails.
    ad = new.get("AdditionalDetails")
    if isinstance(ad, dict):
        tags = ad.get("DocumentTags")
        if not isinstance(tags, list):
            tags = []
        if prefix_slug and prefix_slug not in tags:
            tags.append(prefix_slug)
        ad["DocumentTags"] = tags

    return new


def parse_json(text: str) -> Dict[str, Any]:
    """Parse a JSON string into a dict (for inline examples in .robot files)."""
    return json.loads(text)


def set_internal_document_id(payload: Dict[str, Any], value: str) -> Dict[str, Any]:
    """Return a copy with a known InternalDocumentId (so it can be referenced
    later, e.g. in the media/upload URL). Sets DistributionDetails.
    InternalDocumentId and any top-level internalDocumentId/InternalDocumentId."""
    new = copy.deepcopy(payload)
    dist = new.get("DistributionDetails")
    if isinstance(dist, dict):
        dist["InternalDocumentId"] = value
    for k in ("internalDocumentId", "InternalDocumentId"):
        if k in new:
            new[k] = value
    return new


def set_additional_details(payload: Dict[str, Any],
                           transmission_method: str = "",
                           tag: str = "") -> Dict[str, Any]:
    """Return a copy with AdditionalDetails.TransmissionMethod set and/or a
    DocumentTag appended (both optional)."""
    new = copy.deepcopy(payload)
    ad = new.get("AdditionalDetails")
    if not isinstance(ad, dict):
        ad = {}
        new["AdditionalDetails"] = ad
    if transmission_method:
        ad["TransmissionMethod"] = transmission_method
    if tag:
        tags = ad.get("DocumentTags")
        if not isinstance(tags, list):
            tags = []
        tags.append(tag)
        ad["DocumentTags"] = tags
    return new


def upload_media_file(issuer_tin: str, internal_doc_id: str, file_path: str,
                      content_type: str = "", store_months: int = 1) -> Dict[str, Any]:
    """POST a single attachment to
    /media/upload/{issuer_tin}/{internal_doc_id}?storeDurationMonths=N
    as multipart form-data (field 'File'). Returns a flat result dict with
    status_code, success (per-file), message; also logs an [[APICALL]] line."""
    import mimetypes
    import os as _os

    if _state["session"] is None:
        raise RuntimeError("Call 'Configure Client' in Suite Setup first.")
    base = (_state["base_url"] or "").rstrip("/")
    url = f"{base}/media/upload/{issuer_tin}/{internal_doc_id}?storeDurationMonths={store_months}"
    name = _os.path.basename(file_path)
    ctype = content_type or mimetypes.guess_type(name)[0] or "application/octet-stream"

    with open(file_path, "rb") as fh:
        data = fh.read()
    try:
        resp = _state["session"].post(
            url, headers={"APIKey": _state["api_key"]},
            files={"File": (name, data, ctype)}, timeout=_state["timeout"],
        )
        status = resp.status_code
        raw = resp.text
        try:
            body = resp.json()
        except Exception:
            body = []
        ok = bool(body) and all(
            (it.get("success") is True) for it in body if isinstance(it, dict)
        )
        if status >= 400:
            ok = False
    except requests.RequestException as exc:
        status, raw, body, ok = 0, f"network error: {exc}", [], False

    result = {
        "endpoint": f"/media/upload ({name})",
        "status_code": status,
        "success": ok,
        "message": (raw or "")[:200],
        "mark": "", "uid": "", "signature": "", "input": "",
        "url": "", "raw_text": raw, "body_dict": body if isinstance(body, dict) else {},
        "summary": f"{name}: HTTP {status} {'OK' if ok else 'FAILED'}",
    }
    _log_api_call("POST", f"/media/upload ({name})", result, {})
    return result


def assert_portal_contains(doc_url: str, lang: str, expected) -> str:
    """GET the portal document page in the given language (?lang=el|en) and
    assert every expected substring (e.g. a translated label) is present."""
    sep = "&" if "?" in (doc_url or "") else "?"
    html = requests.get(f"{doc_url}{sep}lang={lang}", timeout=60).text
    missing = [s for s in expected if s not in html]
    if missing:
        raise AssertionError(f"Portal (lang={lang}) missing label(s): {missing}")
    return f"portal (lang={lang}) shows {len(list(expected))} label(s)"


def fetch_attachments(doc_url: str, issuer_tin: str, authentication_code: str,
                      timeout: int = 60) -> List[str]:
    """Return the originalName list of attachments the portal shows for a
    document, via /api/InvoiceAttachments/GetAttachments (same host as the
    document url)."""
    import urllib.parse as _u
    parts = _u.urlsplit(doc_url or "")
    base = f"{parts.scheme}://{parts.netloc}"
    url = base + "/api/InvoiceAttachments/GetAttachments"
    resp = requests.get(
        url, params={"authenticationCode": authentication_code, "issuerTin": issuer_tin},
        timeout=timeout,
    )
    try:
        data = resp.json()
    except Exception:
        data = []
    return [a.get("originalName") for a in data if isinstance(a, dict) and a.get("originalName")]


def assert_attachments_on_portal(doc_url: str, issuer_tin: str,
                                 authentication_code: str, expected_names) -> str:
    """Assert every expected filename appears in the portal's attachment list."""
    expected = [str(n) for n in expected_names]
    found = fetch_attachments(doc_url, issuer_tin, authentication_code)
    found_set = set(found)
    missing = [n for n in expected if n not in found_set]
    if missing:
        raise AssertionError(
            f"Portal attachments mismatch: missing {missing}; found {found}"
        )
    return f"portal shows {len(expected)} attachments: {found}"


def set_distribution_details(payload: Dict[str, Any],
                             shipping_method: str = "",
                             transport_type_code: str = "",
                             p_number: str = "") -> Dict[str, Any]:
    """Return a copy with the given DistributionDetails transport fields set
    (only the non-empty ones): shippingMethod, transportTypeCode (int),
    pNumber."""
    new = copy.deepcopy(payload)
    dist = new.get("DistributionDetails")
    if not isinstance(dist, dict):
        dist = {}
        new["DistributionDetails"] = dist
    if str(shipping_method) != "":
        dist["shippingMethod"] = shipping_method
    if str(transport_type_code) != "":
        dist["transportTypeCode"] = int(transport_type_code)
    if str(p_number) != "":
        dist["pNumber"] = p_number
    return new


def set_delivery_flags(payload: Dict[str, Any],
                       non_obligated: str = "",
                       send_to_etransport: str = "",
                       without_digital: str = "") -> Dict[str, Any]:
    """Return a copy of a delivery-note payload with the transport flags set.
    Each flag accepts "true"/"false"/"null"; an empty string leaves the
    template's value untouched. The existing CounterParty VAT is kept as-is.
    For every flag that ends up TRUE, a DocumentTag with the flag's name is
    appended to AdditionalDetails.DocumentTags (e.g. "nonObligatedRecipient")."""
    def coerce(raw):
        s = str(raw).strip().lower()
        if s in ("true", "1", "yes"):
            return True
        if s in ("false", "0", "no"):
            return False
        return None  # "null" / "none"

    new = copy.deepcopy(payload)
    if str(non_obligated) != "":
        new["nonObligatedRecipient"] = coerce(non_obligated)
    if str(without_digital) != "":
        new["withoutDigitalTransportTracking"] = coerce(without_digital)
    if str(send_to_etransport) != "":
        new["sendToEtransport"] = coerce(send_to_etransport)

    # DocumentTag for each flag that is true
    true_tags = [k for k in ("nonObligatedRecipient",
                             "withoutDigitalTransportTracking",
                             "sendToEtransport") if new.get(k) is True]
    if true_tags:
        ad = new.get("AdditionalDetails")
        if not isinstance(ad, dict):
            ad = {}
            new["AdditionalDetails"] = ad
        tags = ad.get("DocumentTags")
        if not isinstance(tags, list):
            tags = []
        tags.extend(true_tags)
        ad["DocumentTags"] = tags
    return new


def set_delivery_note_marks(payload: Dict[str, Any], marks) -> Dict[str, Any]:
    """Return a copy of payload with deliveryNoteMarks set to the given marks.
    The provider maps this input field to the myDATA XML element
    <multipleConnectedMarks>."""
    new = copy.deepcopy(payload)
    new["deliveryNoteMarks"] = [str(m) for m in marks]
    return new


def fetch_aade_xml(portal_url: str, timeout: int = 60) -> str:
    """GET the myDATA XML of a document from its portal URL + '/aade'."""
    url = (portal_url or "").rstrip("/") + "/aade"
    resp = requests.get(
        url, headers={"Accept": "application/xml,text/html"}, timeout=timeout
    )
    return resp.text


_MCM_RE = re.compile(
    r"<multipleConnectedMarks>\s*([^<\s]+)\s*</multipleConnectedMarks>"
)


def connected_marks_in_xml(xml: str) -> List[str]:
    """All <multipleConnectedMarks> values found in a myDATA XML document."""
    return _MCM_RE.findall(xml or "")


def assert_connected_marks(xml: str, expected_marks) -> str:
    """Assert every expected mark appears as a multipleConnectedMarks in the
    myDATA XML. Raises AssertionError listing any missing marks."""
    expected = [str(m) for m in expected_marks]
    found = connected_marks_in_xml(xml)
    found_set = set(found)
    missing = [m for m in expected if m not in found_set]
    if missing:
        raise AssertionError(
            f"AADE multipleConnectedMarks mismatch: expected {expected}, "
            f"found {found}, missing {missing}"
        )
    return f"multipleConnectedMarks OK ({len(expected)} marks): {found}"


def set_party_vats(payload: Dict[str, Any],
                   issuer_vat: Optional[str] = None,
                   counterparty_vat: Optional[str] = None) -> Dict[str, Any]:
    """Return a copy with the Issuer / CounterParty VAT replaced by the given
    values, but ONLY where such a key already exists (any casing / naming:
    Vat, vat, vatNumber). Templates ship placeholders like "IssuerVat" that
    the invoice endpoints reject with "Authentication failed" unless replaced
    by the authenticated entity's VAT.
    """
    new = copy.deepcopy(payload)

    def set_vat(container_keys, vat):
        if not vat:
            return
        for ck in container_keys:
            party = new.get(ck)
            if isinstance(party, dict):
                for vk in ("Vat", "vat", "vatNumber", "VatNumber"):
                    if vk in party:
                        party[vk] = vat

    set_vat(("Issuer", "issuer"), issuer_vat)
    set_vat(("CounterParty", "counterParty", "Counterpart", "counterpart"),
            counterparty_vat)
    return new


def _deep_merge_inplace(dst: Dict[str, Any], src: Dict[str, Any]) -> None:
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            _deep_merge_inplace(dst[k], v)
        else:
            dst[k] = v


# --------------------------------------------------------------------------- #
# Reporting
# --------------------------------------------------------------------------- #
def format_step_row(case_id, step, label, expected, actual, api_msg,
                    endpoint: str = "") -> str:
    expected_i = int(expected)
    actual_i = int(actual)
    verdict = "PASS" if expected_i == actual_i else "FAIL"
    ep = f" [{endpoint}]" if endpoint else ""
    return (
        f"  [{verdict}] {case_id} step {int(step):>2} | {str(label):<60}"
        f"{ep} | exp={expected_i:<3} got={actual_i:<3} | {api_msg}"
    )


def make_row_dict(case_id, step, label, expected, actual, api,
                  endpoint: str = "") -> Dict[str, Any]:
    expected_i = int(expected)
    actual_i = int(actual)
    return {
        "verdict": "PASS" if expected_i == actual_i else "FAIL",
        "case_id": case_id,
        "step": int(step),
        "label": label,
        "endpoint": endpoint or api.get("endpoint", ""),
        "expected": expected_i,
        "actual": actual_i,
        "success": api.get("success"),
        "message": api.get("message", ""),
        "mark": api.get("mark", ""),
        "uid": api.get("uid", ""),
        "url": api.get("url", ""),
        "signature_short": (str(api.get("signature", "") or "")[:24]),
    }


def render_summary(rows: List[str]) -> str:
    if not rows:
        return "(no test results recorded)"
    total = len(rows)
    passed = sum(1 for r in rows if "[PASS]" in r)
    failed = total - passed
    width = 140
    border = "=" * width
    sub = "-" * width
    lines = [
        "",
        border,
        f"  TEST EXECUTION SUMMARY    total={total}    passed={passed}    failed={failed}",
        border,
    ]
    lines.extend(rows)
    lines.append(sub)
    lines.append(f"  Result: {passed}/{total} steps passed, {failed} failed.")
    if failed:
        lines.append("  Failed steps:")
        for r in rows:
            if "[FAIL]" in r:
                lines.append("   " + r.lstrip())
    lines.append(border)
    return "\n".join(lines)


def write_results_csv(rows: List[Dict[str, Any]], path: str) -> None:
    if not rows:
        return
    fields = [
        "verdict", "case_id", "step", "label", "endpoint",
        "expected", "actual", "success", "message", "mark", "uid",
        "url", "signature_short",
    ]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})
