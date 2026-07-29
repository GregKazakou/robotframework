# InvoiceHelpers.py
# Place this file in the SAME folder as invoices.robot

import copy
from collections import defaultdict

_STRIP_KEYS = {
    "unitPrice", "netTotal", "total", "vatTotal",
    "vatCategory", "IsInformative", "IsHidden", "RecordTypeCode",
    "UnitPrice", "NetTotal", "Total", "VatTotal", "VatCategory",
}

_DN_DEFAULTS = {
    "quantityIn15Deg":           None,
    "fuelCode":                  None,
    "recordTypeCode":            0,
    "movePurposeLineCode":       0,
    "otherMovePurposeLineTitle": None,
    "taricNo":                   "0123456789",
}


def get_details_from_payload(payload: dict) -> list:
    known = ["details", "Details", "items", "Items", "lineItems", "LineItems", "Lines"]
    for key in known:
        val = payload.get(key)
        if isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
            return val
    for key, val in payload.items():
        if isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
            return val
    actual = list(payload.keys())
    raise ValueError(f"Could not find a non-empty list-of-dicts. Keys: {actual}")


def transform_items_for_dn(raw_items: list) -> list:
    result = []
    for item in raw_items:
        new_item = {k: v for k, v in item.items() if k not in _STRIP_KEYS}
        new_item.pop("VatCategoryCode", None)
        new_item["vatCategoryCode"] = 8
        new_item.pop("IncomeClassification", None)
        new_item.pop("incomeClassification", None)
        new_item["IncomeClassification"] = {"ClassificationCategoryCode": "category3"}
        for key, default in _DN_DEFAULTS.items():
            new_item.setdefault(key, default)
        result.append(new_item)
    return result


def compute_summaries(items: list) -> dict:
    """
    Compute Summaries + VatAnalysis + per-classification totals
    from a list of 1.1 detail dicts.

    Each item must have:
        netTotal / NetTotal
        vatTotal / VATTotal / VatTotal
        total    / Total
        vatCategoryCode / VatCategoryCode
        vatCategory / VatCategory  (e.g. "24%")
        IncomeClassification / incomeClassification with
            ClassificationTypeCode and ClassificationCategoryCode
    """

    total_net   = 0.0
    total_vat   = 0.0
    total_gross = 0.0

    # vat_code -> {name, pct, net, vat}
    vat_buckets = {}

    # (type_code, cat_code) -> amount
    inc_class_buckets = defaultdict(float)

    for item in items:
        net   = float(item.get("netTotal")   or item.get("NetTotal")  or 0)
        vat   = float(item.get("vatTotal")   or item.get("VATTotal")  or item.get("VatTotal") or 0)
        gross = float(item.get("total")      or item.get("Total")     or net + vat)

        total_net   += net
        total_vat   += vat
        total_gross += gross

        # VAT analysis
        vat_code = item.get("vatCategoryCode") or item.get("VatCategoryCode") or 0
        vat_name = item.get("vatCategory")     or item.get("VatCategory") or ""
        if vat_code not in vat_buckets:
            # derive percentage from name e.g. "24%" -> 24
            try:
                pct = float(str(vat_name).replace("%", "").strip())
            except Exception:
                pct = 0.0
            vat_buckets[vat_code] = {"name": vat_name, "pct": pct, "net": 0.0, "vat": 0.0}
        vat_buckets[vat_code]["net"] += net
        vat_buckets[vat_code]["vat"] += vat

        # Income classification
        ic = item.get("IncomeClassification") or item.get("incomeClassification") or {}
        tc  = ic.get("ClassificationTypeCode")     or ic.get("classificationTypeCode")     or ""
        cc  = ic.get("ClassificationCategoryCode") or ic.get("classificationCategoryCode") or ""
        amt = float(ic.get("amount") or ic.get("Amount") or net)
        if tc or cc:
            inc_class_buckets[(tc, cc)] += amt

    # Round everything to 2 decimal places
    total_net   = round(total_net,   2)
    total_vat   = round(total_vat,   2)
    total_gross = round(total_gross, 2)

    summaries = {
        "TotalCatalogNetAmount": total_net,
        "TotalNetAmount":        total_net,
        "TotalVATAmount":        total_vat,
        "TotalWithheldAmount":   0,
        "totalFeesAmount":       0,
        "totalOtherTaxesAmount": 0,
        "TotalStampDutyAmount":  0,
        "TotalDeductionsAmount": 0,
        "TotalGrossValue":       total_gross,
        "totalPayableAmount":    total_gross,
    }

    vat_analysis = []
    for code, b in vat_buckets.items():
        vat_analysis.append({
            "Name":            b["name"],
            "Percentage":      b["pct"],
            "VatAmount":       round(b["vat"], 2),
            "UnderlyingValue": round(b["net"], 2),
        })

    income_classifications = []
    for idx, ((tc, cc), amt) in enumerate(inc_class_buckets.items(), start=1):
        entry = {"ClassificationCategoryCode": cc, "amount": round(amt, 2), "id": idx}
        if tc:
            entry["ClassificationTypeCode"] = tc
        income_classifications.append(entry)

    return {
        "summaries":           summaries,
        "VatAnalysis":         vat_analysis,
        "incomeClassifications": income_classifications,
    }


def slice_list(items: list, start: int, end: int) -> list:
    return items[int(start):int(end)]


def renumber_lines(items: list) -> list:
    result = []
    for idx, item in enumerate(items, start=1):
        new_item = copy.deepcopy(item)
        new_item.pop("LineNo", None)
        new_item["lineNo"] = idx
        result.append(new_item)
    return result


def list_length(items: list) -> int:
    return len(items)


def inject_items_and_fix_summaries(payload: dict, items: list) -> dict:
    """
    1. Remove both 'Details' (PascalCase) and 'details' (camelCase) from payload
    2. Inject items under 'details' (camelCase, what the API expects)
    3. Recompute Summaries and VatAnalysis from the items
    4. Return the updated payload
    """
    result = copy.deepcopy(payload)

    # Remove any existing details key regardless of case
    for key in list(result.keys()):
        if key.lower() == "details":
            del result[key]

    # Renumber and inject
    numbered = renumber_lines(items)
    result["details"] = numbered

    # Recompute summaries
    computed = compute_summaries(numbered)
    result["Summaries"]   = computed["summaries"]
    result["VatAnalysis"] = computed["VatAnalysis"]

    return result


# =============================================================================
# dateIssued MATRIX HELPERS  (used by dateIssued_matrix.robot)
# =============================================================================

import re
from datetime import datetime

# Offset flavours applied to every base time. Order defines the variant
# numbering (1..4) within each time group.
_OFFSET_FLAVOURS = [
    ("NAIVE", ""),        # no timezone info
    ("Z",     "Z"),       # UTC 'Z'
    ("P03",   "+03:00"),  # Greece standard offset
    ("P00",   "+00:00"),  # zero offset, numeric
]

# Time-of-day groups: 'MID' = today at midnight, 'NOW' = current wall clock.
_GROUPS = ["MID", "NOW"]

_HTML_DT = re.compile(
    r"(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*"
    r"(π\.?μ\.?|μ\.?μ\.?)",   # π.μ. (AM) | μ.μ. (PM)
    re.IGNORECASE,
)
_BOLD_CELL = re.compile(
    r"<td[^>]*font-weight-bold[^>]*>(.*?)</td>", re.IGNORECASE | re.DOTALL
)


def build_datetime_variants():
    """Return the 8 dateIssued variants (4 offset flavours x 2 time groups).

    Each variant is a dict: index, group, offset_label, offset, date_issued.
    'now' is snapshotted once so all variants of a run share one wall clock.
    """
    now = datetime.now().replace(microsecond=0)
    bases = {
        "MID": now.replace(hour=0, minute=0, second=0),
        "NOW": now,
    }

    variants = []
    idx = 0
    for group in _GROUPS:
        base_str = bases[group].strftime("%Y-%m-%dT%H:%M:%S")
        for label, suffix in _OFFSET_FLAVOURS:
            idx += 1
            variants.append({
                "index":        idx,
                "group":        group,
                "offset_label": label,
                "offset":       suffix,
                "date_issued":  base_str + suffix,
            })
    return variants


def get_variant_field(variant, field):
    """Return one field from a variant dict (keeps the .robot readable)."""
    if field not in variant:
        raise KeyError(f"Variant has no field '{field}'. Keys: {list(variant)}")
    return variant[field]


def build_series(series_prefix, variant):
    """Run-identifiable Series token, e.g. FNB111-NOW-P03-20260728-120043."""
    wall = _parse_wallclock(variant["date_issued"])
    stamp = wall.strftime("%Y%m%d-%H%M%S")
    return f"{series_prefix}-{variant['group']}-{variant['offset_label']}-{stamp}"


def verify_sent_vs_response_format(sent_dt, resp_dt, strict=True):
    """Assert the response echoes the same offset flavour that was sent.

    strict=True  -> exact match ('Z' != '+00:00').
    strict=False -> 'Z' and '+00:00' are treated as equivalent (UTC).
    """
    strict = _to_bool(strict)
    sent_f = _offset_flavour(sent_dt)
    resp_f = _offset_flavour(resp_dt)

    ok = (sent_f == resp_f) if strict else (_utc_norm(sent_f) == _utc_norm(resp_f))
    if not ok:
        raise AssertionError(
            f"dateIssued format mismatch (strict={strict}): "
            f"sent flavour '{sent_f}' ({sent_dt}) != "
            f"response flavour '{resp_f}' ({resp_dt})"
        )
    return resp_f


def verify_response_datetime_skew(sent_dt, resp_dt, max_minutes=10):
    """Assert response wall-clock time is within max_minutes of what was sent."""
    max_minutes = float(max_minutes)
    sent_wc = _parse_wallclock(sent_dt)
    resp_wc = _parse_wallclock(resp_dt)
    diff_min = abs((resp_wc - sent_wc).total_seconds()) / 60.0
    if diff_min > max_minutes:
        raise AssertionError(
            f"dateIssued skew too large: sent {sent_dt} vs response {resp_dt} "
            f"= {diff_min:.2f} min (max {max_minutes})"
        )
    return diff_min


def verify_html_datetime(html, sent_dt, max_minutes=10):
    """Extract the portal bold-cell datetime and assert it matches sent wall clock."""
    max_minutes = float(max_minutes)
    parsed = _extract_html_datetime(html)
    if parsed is None:
        raise AssertionError(
            "Could not find a dd/mm/yyyy HH:MM π.μ./μ.μ. "
            "datetime in the portal HTML."
        )
    html_wc, raw = parsed
    sent_wc = _parse_wallclock(sent_dt)
    diff_min = abs((html_wc - sent_wc).total_seconds()) / 60.0
    if diff_min > max_minutes:
        raise AssertionError(
            f"Portal datetime skew too large: sent {sent_dt} vs portal '{raw}' "
            f"= {diff_min:.2f} min (max {max_minutes})"
        )
    return raw


# ------------------------------------------------------------------ internals

def _offset_flavour(dt_str):
    """Classify the wire-format offset of an ISO datetime string."""
    s = (dt_str or "").strip()
    if s.endswith("Z"):
        return "Z"
    m = re.search(r"([+-]\d{2}):?(\d{2})$", s)
    if m:
        return f"{m.group(1)}:{m.group(2)}"
    return "NAIVE"


def _utc_norm(flavour):
    return "UTC" if flavour in ("Z", "+00:00") else flavour


def _to_bool(value):
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ("1", "true", "yes", "y")


def _parse_wallclock(dt_str):
    """Parse an ISO string to a *naive* datetime (wall clock, tz stripped)."""
    s = (dt_str or "").strip()
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        return dt.replace(tzinfo=None)
    except ValueError:
        core = re.sub(r"(Z|[+-]\d{2}:?\d{2})$", "", s)
        return datetime.fromisoformat(core)


def _is_pm(meridiem):
    """Greek: μ.μ. = PM (afternoon), π.μ. = AM (morning)."""
    s = meridiem.strip().lower().replace(".", "").replace(" ", "")
    return s.startswith("μ")


def _extract_html_datetime(html):
    html = html or ""
    # Prefer bold cells (where the portal renders the issue datetime),
    # fall back to scanning the whole document.
    candidates = _BOLD_CELL.findall(html)
    candidates.append(html)
    for chunk in candidates:
        m = _HTML_DT.search(chunk)
        if not m:
            continue
        day, month, year, hour, minute, second, mer = m.groups()
        hour = int(hour)
        minute = int(minute)
        second = int(second) if second else 0
        if _is_pm(mer):
            if hour != 12:
                hour += 12
        elif hour == 12:      # 12 π.μ. == midnight
            hour = 0
        dt = datetime(int(year), int(month), int(day), hour, minute, second)
        return dt, m.group(0).strip()
    return None

