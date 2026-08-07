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
        return _parse_response(path, resp, payload)
    except requests.exceptions.Timeout:
        return _network_error_dict(path, payload, "client-side timeout")
    except requests.RequestException as exc:
        return _network_error_dict(path, payload, f"network error: {exc}")


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


def apply_unique_fields(payload: Dict[str, Any], prefix: str = "EX") -> Dict[str, Any]:
    """Return a copy of `payload` with unique identifiers, so the same example
    JSON can be POSTed repeatedly without duplicate-document rejections.

    Only keys that ALREADY exist in the payload are touched (both camelCase
    and PascalCase), so it is safe on any template:
      * Series / series           -> {prefix}-<timestamp>
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
    series = f"{prefix}-{stamp}"
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
    if isinstance(dist, dict) and "InternalDocumentId" in dist:
        dist["InternalDocumentId"] = guid

    return new


def parse_json(text: str) -> Dict[str, Any]:
    """Parse a JSON string into a dict (for inline examples in .robot files)."""
    return json.loads(text)


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
