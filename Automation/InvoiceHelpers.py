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
from datetime import datetime, time as _time, timezone, timedelta

# Europe/Athens with DST support. On Windows, zoneinfo needs the 'tzdata'
# pip package; if it is missing we fall back to a fixed offset.
try:
    from zoneinfo import ZoneInfo
    _ATHENS = ZoneInfo("Europe/Athens")
    datetime.now(_ATHENS)  # force tz-db lookup so a missing tzdata fails here
except Exception:
    _ATHENS = timezone(timedelta(hours=3), name="EEST-fallback")


def athens_offset_suffix():
    """Current Europe/Athens UTC offset as '+HH:MM' (DST-aware:
    +03:00 in summer / +02:00 in winter)."""
    total = int(datetime.now(_ATHENS).utcoffset().total_seconds())
    sign = "+" if total >= 0 else "-"
    total = abs(total)
    return f"{sign}{total // 3600:02d}:{(total % 3600) // 60:02d}"


def _offset_flavours():
    """Offset flavours applied to every base time. Order defines the variant
    numbering (1..4) within each time group. The Greece offset is computed
    at runtime so the matrix stays valid across DST changes."""
    ath = athens_offset_suffix()
    return [
        ("NAIVE", ""),      # no timezone info -> treated as Greece local
        ("Z",     "Z"),     # UTC 'Z'          -> must convert to Greece
        ("ATH",   ath),     # current Greece offset (was hardcoded '+03:00')
        ("P00",   "+00:00"),  # zero offset, numeric -> same instant as 'Z'
    ]

# Time-of-day groups: 'MID' = today at midnight, 'NOW' = current wall clock.
_GROUPS = ["MID", "NOW"]

# Invoice portal: dd/mm/yyyy h:mm π.μ./μ.μ. (12-hour + Greek meridiem)
_HTML_DT = re.compile(
    r"(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*"
    r"(π\.?μ\.?|μ\.?μ\.?)",   # π.μ. (AM) | μ.μ. (PM)
    re.IGNORECASE,
)
# Receipt portal: dd-mm-yyyy HH:MM:SS (24-hour, no meridiem)
_HTML_DT_24H = re.compile(
    r"(\d{1,2})[-/](\d{1,2})[-/](\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?"
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
        for label, suffix in _offset_flavours():
            idx += 1
            variants.append({
                "index":        idx,
                "group":        group,
                "offset_label": label,
                "offset":       suffix,
                "date_issued":  base_str + suffix,
            })
    return variants


def find_variant(variants, group, offset_label):
    """Return the variant dict matching (group, offset_label),
    e.g. ('MID', 'Z'). Lets each Robot test case address one exact case."""
    for v in variants:
        if v["group"] == group and v["offset_label"] == offset_label:
            return v
    known = [(v["group"], v["offset_label"]) for v in variants]
    raise ValueError(f"No variant {group}/{offset_label}. Known: {known}")


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


# =============================================================================
# GR-TIMEZONE-AWARE CHECKS  (business rules of the einvoice app)
# =============================================================================
#
# The application's documented behaviour:
#   1. If the payload time is literally 00:00:00 -> the app stamps the
#      document with the CURRENT time at submission.
#   2. If the payload carries a UTC marker ('Z' or '+00:00') -> the app
#      respects it and converts the instant to Greece local time.
#   3. A naive datetime (no offset) is treated as already Greece local.
#   4. The portal always displays Europe/Athens wall-clock time.

def expected_athens_datetime(sent_dt, submitted_at=None):
    """Return (expected_athens_wallclock, rule_label) for a sent dateIssued.

    submitted_at: optional ISO string / aware datetime of the moment the
    invoice was POSTed; defaults to 'now'. Only used by the midnight rule.
    """
    wall = _parse_wallclock(sent_dt)

    # Rule 1 — literal midnight => app stamps submission time
    if wall.time() == _time(0, 0, 0):
        base = submitted_at or datetime.now(_ATHENS)
        if isinstance(base, str):
            base = _parse_aware_athens(base)
        return base.astimezone(_ATHENS).replace(tzinfo=None), "MIDNIGHT->SUBMISSION_TIME"

    # Rules 2 & 3 — respect the offset (naive = Athens) and convert to Athens
    aware = _parse_aware_athens(sent_dt)
    flavour = _offset_flavour(sent_dt)
    rule = "NAIVE=ATHENS" if flavour == "NAIVE" else f"{flavour}->ATHENS"
    return aware.astimezone(_ATHENS).replace(tzinfo=None), rule


def verify_response_datetime_gr(sent_dt, resp_dt, max_minutes=10, submitted_at=None):
    """Assert the response dateIssued matches the app's GR rules.

    UAT observation (2026-07): the offset label on the response is not
    reliable — /Receipt & 8.6 return Athens wall clock labelled 'Z', while
    11.1 returns proper UTC '+00:00'. So the response is accepted if EITHER
    interpretation matches the expected Athens time:
      * aware:     parse with its offset and convert to Athens
      * wallclock: take the digits as Athens time, ignore the label
    The portal HTML check remains the strict authority on display.
    """
    max_minutes = float(max_minutes)
    expected, rule = expected_athens_datetime(sent_dt, submitted_at)

    aware = _parse_aware_athens(resp_dt).astimezone(_ATHENS).replace(tzinfo=None)
    wall = _parse_wallclock(resp_dt)

    diff_aware = abs((aware - expected).total_seconds()) / 60.0
    diff_wall = abs((wall - expected).total_seconds()) / 60.0

    if diff_aware <= max_minutes:
        return (f"rule={rule} expected≈{expected:%H:%M:%S} response={resp_dt} "
                f"[aware] diff={diff_aware:.2f}min")
    if diff_wall <= max_minutes:
        return (f"rule={rule} expected≈{expected:%H:%M:%S} response={resp_dt} "
                f"[wallclock — offset label unreliable] diff={diff_wall:.2f}min")

    raise AssertionError(
        f"Response dateIssued wrong for rule [{rule}]: sent={sent_dt} "
        f"expected≈{expected:%Y-%m-%d %H:%M:%S} (Athens) but response={resp_dt} "
        f"(aware={aware:%H:%M:%S} diff {diff_aware:.1f}min / "
        f"wallclock={wall:%H:%M:%S} diff {diff_wall:.1f}min; max {max_minutes})"
    )


def verify_html_datetime_gr(html, sent_dt, max_minutes=10, submitted_at=None):
    """Assert the portal displays the CORRECT Greece local time for the
    dateIssued that was sent, per the app's GR rules."""
    max_minutes = float(max_minutes)
    expected, rule = expected_athens_datetime(sent_dt, submitted_at)
    parsed = _extract_html_datetime(html)
    if parsed is None:
        raise AssertionError(
            "Could not find a dd/mm/yyyy HH:MM π.μ./μ.μ. "
            "datetime in the portal HTML."
        )
    html_wc, raw = parsed
    diff_min = abs((html_wc - expected).total_seconds()) / 60.0
    if diff_min > max_minutes:
        raise AssertionError(
            f"Portal shows WRONG Greece time for rule [{rule}]: sent={sent_dt} "
            f"expected≈{expected:%d/%m/%Y %H:%M} (Athens) but portal shows "
            f"'{raw}', diff {diff_min:.2f} min (max {max_minutes})"
        )
    return f"rule={rule} expected≈{expected:%d/%m/%Y %H:%M} portal='{raw}' diff={diff_min:.2f}min"


# ------------------------------------------------------------------ internals

def _parse_aware_athens(dt_str):
    """Parse an ISO datetime string to an AWARE datetime.
    Naive strings (no offset) are interpreted as Europe/Athens local time."""
    s = (dt_str or "").strip()
    dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=_ATHENS)
    return dt


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
    # Prefer bold cells (where the invoice portal renders the issue datetime),
    # fall back to scanning the whole document.
    candidates = _BOLD_CELL.findall(html)
    candidates.append(html)

    # 1) Invoice portal: 12-hour with Greek meridiem
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

    # 2) Receipt portal: 24-hour dd-mm-yyyy HH:MM:SS, no meridiem
    for chunk in candidates:
        m = _HTML_DT_24H.search(chunk)
        if not m:
            continue
        day, month, year, hour, minute, second = m.groups()
        dt = datetime(int(year), int(month), int(day),
                      int(hour), int(minute), int(second) if second else 0)
        return dt, m.group(0).strip()

    return None

