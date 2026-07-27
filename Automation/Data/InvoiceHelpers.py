"""
InvoiceHelpers.py

Helpers for the 8-variant dateIssued test suite (8.4 / 8.6 / 11.1).

Provides:
  * The 8 dateIssued variants (fixed-midnight + current-time), each in the
    4 offset flavours: naive, Z (UTC), +03:00, +00:00.
  * A short, human-readable "series suffix" per variant so you can tell
    which run produced which document.
  * Verification that the dateIssued returned by the API is in the SAME
    format flavour that was sent, and within a few minutes of it.
  * Extraction + comparison of the "01/07/2026 12:00 μ.μ." style <td>
    value from the returned portal HTML.

Robot Framework auto-maps method names to keywords, e.g.
    Build Datetime Variants
    Get Variant Field
    Verify Sent Vs Response Format
    Verify Response Datetime Skew
    Verify Html Datetime
"""

import re
import datetime as _dt
from robot.api import logger

# Robot library scope: one instance reused across the suite.
ROBOT_LIBRARY_SCOPE = "GLOBAL"

# Default tolerance (minutes) for "same time within a few minutes".
DEFAULT_SKEW_MINUTES = 10

# The four offset flavours we test. `key` is a short token that also feeds
# the Series suffix so a human can eyeball which run it was.
_FLAVOURS = [
    {"key": "NAIVE", "label": "naive",  "suffix": "N"},   # ...T00:00:00
    {"key": "Z",     "label": "utcZ",   "suffix": "Z"},   # ...T00:00:00Z
    {"key": "P03",   "label": "+03:00", "suffix": "P03"}, # ...T00:00:00+03:00
    {"key": "P00",   "label": "+00:00", "suffix": "P00"}, # ...T00:00:00+00:00
]


# ---------------------------------------------------------------------------
# Internal formatting
# ---------------------------------------------------------------------------

def _apply_flavour(base_dt, flavour_key):
    """Return an ISO-8601 string for base_dt in the requested flavour.

    base_dt is a *naive* datetime (no tzinfo). We never actually convert the
    clock — we only append the textual offset. That is deliberate: we want to
    assert on the exact string form the API echoes back.
    """
    stamp = base_dt.strftime("%Y-%m-%dT%H:%M:%S")
    if flavour_key == "NAIVE":
        return stamp
    if flavour_key == "Z":
        return stamp + "Z"
    if flavour_key == "P03":
        return stamp + "+03:00"
    if flavour_key == "P00":
        return stamp + "+00:00"
    raise ValueError("Unknown flavour key: %s" % flavour_key)


def _midnight_today():
    now = _dt.datetime.now()
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


def _now_seconds():
    # current datetime, seconds precision, no microseconds
    return _dt.datetime.now().replace(microsecond=0)


# ---------------------------------------------------------------------------
# Variant construction
# ---------------------------------------------------------------------------

def build_datetime_variants():
    """Build the 8 test variants.

    Variants 1-4  -> fixed midnight (00:00:00) of *today*, 4 offset flavours.
    Variants 5-8  -> current datetime (real HH:MM:SS), 4 offset flavours.

    Returns a list of dicts (Robot sees them as a list of dictionaries). Each:
        index        : 1..8
        group        : 'MIDNIGHT' | 'NOW'
        flavour      : 'NAIVE' | 'Z' | 'P03' | 'P00'
        date_issued  : the string to inject into dateIssued
        base_iso     : the naive 'YYYY-MM-DDTHH:MM:SS' with no offset (for skew math)
        has_offset   : bool
        offset_label : human label ('naive','utcZ','+03:00','+00:00')
        series_suffix: short token for the Series field, e.g. 'MID-Z' / 'NOW-P03'
    """
    midnight = _midnight_today()
    now_s = _now_seconds()

    variants = []
    idx = 0
    for group, base, gtoken in (
        ("MIDNIGHT", midnight, "MID"),
        ("NOW", now_s, "NOW"),
    ):
        for fl in _FLAVOURS:
            idx += 1
            variants.append(
                {
                    "index": idx,
                    "group": group,
                    "flavour": fl["key"],
                    "offset_label": fl["label"],
                    "has_offset": fl["key"] != "NAIVE",
                    "date_issued": _apply_flavour(base, fl["key"]),
                    "base_iso": base.strftime("%Y-%m-%dT%H:%M:%S"),
                    "series_suffix": "%s-%s" % (gtoken, fl["suffix"]),
                }
            )
    return variants


def get_variant_field(variant, field):
    """Tiny accessor so .robot can read a dict field without Collections gymnastics."""
    return variant[field]


def build_series(prefix, variant):
    """Build a Series value carrying a representative datetime token.

    Example -> 'FNB-RETAIL-NOW-P03-20260701-120043'
    The suffix (group+flavour) plus a compact timestamp lets you identify the
    exact run at a glance from the portal / results.csv.
    """
    stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return "%s-%s-%s" % (prefix, variant["series_suffix"], stamp)


# ---------------------------------------------------------------------------
# Format detection / comparison
# ---------------------------------------------------------------------------

# Matches an ISO datetime and captures the offset portion (if any).
#   group 'offset' is one of: '' , 'Z', '+03:00', '+00:00', '-05:30', ...
_ISO_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"      # date + time
    r"(?:\.\d+)?"                                 # optional fractional seconds
    r"(?P<offset>Z|[+-]\d{2}:?\d{2})?$"           # optional offset
)


def _flavour_of(value):
    """Classify a datetime string into one of our flavour keys.

    Returns 'NAIVE' | 'Z' | 'P03' | 'P00' | 'OTHER:<offset>'.
    Fractional seconds are ignored for the purpose of flavour (the API echoes
    e.g. '...T12:00:43.148Z' for a sent '...T12:00:43Z' — still flavour Z).
    """
    m = _ISO_RE.match(value.strip())
    if not m:
        return "OTHER:UNPARSEABLE"
    off = m.group("offset")
    if off is None:
        return "NAIVE"
    if off == "Z":
        return "Z"
    norm = off.replace(":", "")
    if norm in ("+0300",):
        return "P03"
    if norm in ("+0000", "-0000"):
        return "P00"
    return "OTHER:%s" % off


def verify_sent_vs_response_format(sent, response, strict=True):
    """Assert the response dateIssued has the SAME offset flavour as what we sent.

    'Same format' here == same offset flavour (naive vs Z vs +03:00 vs +00:00).
    Fractional seconds present only in the response are allowed and expected.

    Raises AssertionError on mismatch. Returns a dict of the classification
    for logging.
    """
    sent_fl = _flavour_of(sent)
    resp_fl = _flavour_of(response)

    logger.info(
        "Format check: sent=%r (%s) response=%r (%s)"
        % (sent, sent_fl, response, resp_fl)
    )

    # Note the semantic equivalence of Z and +00:00 as a helpful diagnostic,
    # but by default we still require an EXACT flavour match because the point
    # of the test is to verify the API preserves the exact wire format.
    if sent_fl != resp_fl:
        equivalent = {sent_fl, resp_fl} == {"Z", "P00"}
        if equivalent and not strict:
            logger.warn(
                "Flavours differ but are UTC-equivalent (Z vs +00:00); "
                "strict=False so treating as pass."
            )
        else:
            raise AssertionError(
                "dateIssued format mismatch: sent flavour %s (%r) "
                "but response flavour %s (%r)"
                % (sent_fl, sent, resp_fl, response)
            )

    return {"sent_flavour": sent_fl, "response_flavour": resp_fl}


def _parse_to_naive_wallclock(value):
    """Parse an ISO string to a naive datetime representing its WALL CLOCK.

    We intentionally drop the offset and keep the literal H:M:S, because the
    'same time within a few minutes' check compares the displayed clock value,
    not an absolute instant. (Sent 12:00:43+03:00 vs response 12:00:45+03:00
    should be 2s apart, not 3h.)
    """
    m = _ISO_RE.match(value.strip())
    if not m:
        raise AssertionError("Cannot parse datetime: %r" % value)
    # Strip trailing offset / Z and fractional seconds for a clean parse.
    core = value.strip()
    core = re.sub(r"(Z|[+-]\d{2}:?\d{2})$", "", core)
    core = re.sub(r"\.\d+$", "", core)
    return _dt.datetime.strptime(core, "%Y-%m-%dT%H:%M:%S")


def verify_response_datetime_skew(sent, response, max_minutes=DEFAULT_SKEW_MINUTES):
    """Assert response wall-clock time is within max_minutes of the sent one.

    Compares literal wall-clock (offset ignored). Raises on violation.
    Returns the delta in seconds (float).
    """
    a = _parse_to_naive_wallclock(sent)
    b = _parse_to_naive_wallclock(response)
    delta = abs((b - a).total_seconds())
    limit = float(max_minutes) * 60.0
    logger.info(
        "Skew check: sent=%s response=%s delta=%.1fs limit=%.0fs"
        % (a.isoformat(), b.isoformat(), delta, limit)
    )
    if delta > limit:
        raise AssertionError(
            "dateIssued time skew too large: %.1fs (> %.0fs). "
            "sent=%r response=%r" % (delta, limit, sent, response)
        )
    return delta


# ---------------------------------------------------------------------------
# HTML portal verification
# ---------------------------------------------------------------------------

# Greek am/pm markers used by the portal: 'π.μ.' (AM) / 'μ.μ.' (PM).
# The <td> looks like:  <td class="font-weight-bold">01/07/2026 12:00 μ.μ.</td>
_TD_RE = re.compile(
    r'<td[^>]*class="[^"]*font-weight-bold[^"]*"[^>]*>\s*'
    r'(?P<dt>\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}\s*[πμ]\.μ\.)\s*</td>',
    re.IGNORECASE | re.UNICODE,
)

# Fallback: any dd/mm/yyyy HH:MM (π.μ.|μ.μ.) anywhere in the HTML.
_ANY_GR_DT_RE = re.compile(
    r'(?P<dt>\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}\s*[πμ]\.μ\.)',
    re.UNICODE,
)


def extract_html_datetime(html):
    """Pull the bold-cell 'dd/mm/yyyy HH:MM π.μ./μ.μ.' string from portal HTML.

    Tries the font-weight-bold <td> first, then falls back to the first
    Greek-formatted datetime found. Returns the raw matched string.
    Raises AssertionError if none found.
    """
    m = _TD_RE.search(html)
    if not m:
        m = _ANY_GR_DT_RE.search(html)
    if not m:
        raise AssertionError(
            "No 'dd/mm/yyyy HH:MM π.μ./μ.μ.' datetime found in portal HTML."
        )
    found = m.group("dt")
    logger.info("HTML datetime extracted: %r" % found)
    return found


def _greek_dt_to_naive(text):
    """Convert '01/07/2026 12:00 μ.μ.' -> naive datetime (24h wall clock)."""
    t = re.sub(r"\s+", " ", text.strip())
    m = re.match(
        r"(\d{2})/(\d{2})/(\d{4})\s+(\d{1,2}):(\d{2})\s*([πμ])\.μ\.",
        t,
        re.UNICODE,
    )
    if not m:
        raise AssertionError("Unrecognised Greek datetime: %r" % text)
    dd, mm, yyyy, hh, minute, ampm = m.groups()
    hh = int(hh)
    minute = int(minute)
    # π.μ. = AM, μ.μ. = PM
    is_pm = ampm == "μ"
    if is_pm and hh != 12:
        hh += 12
    if (not is_pm) and hh == 12:
        hh = 0
    return _dt.datetime(int(yyyy), int(mm), int(dd), hh, minute, 0)


def verify_html_datetime(html, sent, max_minutes=DEFAULT_SKEW_MINUTES):
    """Extract the portal <td> datetime and assert it is within max_minutes
    of the wall-clock time we sent.

    Note: the portal shows minute precision only, so a 0-59s rounding gap is
    normal; max_minutes absorbs it. Returns dict with extracted + delta.
    """
    found = extract_html_datetime(html)
    html_dt = _greek_dt_to_naive(found)
    sent_dt = _parse_to_naive_wallclock(sent)
    delta = abs((html_dt - sent_dt).total_seconds())
    limit = float(max_minutes) * 60.0
    logger.info(
        "HTML skew: html=%s sent=%s delta=%.1fs limit=%.0fs"
        % (html_dt.isoformat(), sent_dt.isoformat(), delta, limit)
    )
    if delta > limit:
        raise AssertionError(
            "Portal HTML datetime %r (%s) differs from sent %r by %.1fs (> %.0fs)."
            % (found, html_dt.isoformat(), sent, delta, limit)
        )
    return {"html_value": found, "html_dt": html_dt.isoformat(), "delta_seconds": delta}
