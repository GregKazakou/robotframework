#!/usr/bin/env python3
"""
Build an HTML email body from Robot Framework's combined output.xml.

Usage (in CI):
    python scripts/build_email_html.py combined/output.xml email_body.html

Optional environment variables (set automatically by GitHub Actions):
    GITHUB_REPOSITORY   e.g. SirAlcan/robotframework
    GITHUB_RUN_ID       e.g. 25207523652
    GITHUB_SERVER_URL   default https://github.com

Output: Outlook-robust HTML. Every table is fixed-width (px) with
table-layout:fixed, everything is left-aligned, and long unbreakable
strings (URLs, API errors) get soft break points, so Outlook never needs
a horizontal scrollbar.
"""

from __future__ import annotations

import json
import os
import re
import sys
from xml.etree import ElementTree as ET


# ────────────────────────── Layout constants ─────────────────────────────
EMAIL_W   = 600           # outer email width (px)
PAD_X     = 24            # left/right padding of the card
CONTENT_W = EMAIL_W - 2 * PAD_X    # 552 usable px inside the padding


# ────────────────────────── Palette (email-safe) ──────────────────────────
C = {
    "bg":        "#eef1f4",
    "card":      "#ffffff",
    "border":    "#e2e6ea",
    "border2":   "#eef1f4",
    "text":      "#1b2430",
    "muted":     "#5a6675",
    "faint":     "#8a94a1",
    "ok_bg":     "#e7f4ea",
    "ok_text":   "#1f6b3a",
    "ok_dot":    "#2e9e54",
    "warn_dot":  "#c8871a",
    "warn_bg":   "#fbf1dc",
    "fail_bg":   "#fbeaea",
    "fail_soft": "#f6d6d6",
    "fail_text": "#8a2020",
    "fail_dark": "#5e1515",
    "fail_dot":  "#c0392b",
    "accent":    "#0f6ea3",
    "accent_bg": "#e3eff6",
}

MONO = "Consolas,'Courier New',monospace"
SANS = "-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif"


# ── Suite explanations (matched by keyword in the suite name) ─────────────
SUITE_INFO = [
    ("dateissued",       "Ζώνες ώρας στο dateIssued — 8 μορφές × 4 τύποι παραστατικών"),
    ("fnb_internalid",   "Μοναδικό InternalID σε FNB παραστατικά"),
    ("fnb flows",        "FNB 8.6 / 11.1 — έκδοση / χρεωστικό / πιστωτικό / ακύρωση / Κλειστήρι"),
    ("fnb",              "FNB (8.6 / 11.1)"),
    ("pos flows",        "Ροές POS: signpos → 8.4/11.1 → validate / updatePayment"),
    ("receipts",         "Αποδείξεις λιανικής (8.4) με InternalID"),
    ("dn life cycle",    "Ψηφιακή Διακίνηση Αποθεμάτων Β΄ Φάση — κύκλος ζωής ΔΑ"),
    ("notification",     "Ειδοποιήσεις παραστατικών (email / SMS / viber - Hyperlink & Attachment)"),
    ("api examples",     "Playground παραδειγμάτων API"),
    ("hotdog",           "UI tests: login, επιλογή εταιρείας, διαχείριση χρηστών"),
]

# ── Error-code hints (myDATA / provider) shown next to a failure ──────────
ERROR_HINTS = {
    "229": "Απόκλιση ΦΠΑ ανά γραμμή πάνω από την ανοχή (fuel)",
    "238": "IssueDate διαφορετικό από την τρέχουσα ημερομηνία",
    "280": "DispatchDate πρέπει να είναι ≥ σημερινή ημερομηνία",
    "289": "Counterparty VAT πρέπει να είναι 000000000",
    "290": "Ασύμβατα flags: nonObligated + withoutDigital μαζί",
}


# ────────────────────────── Parsing helpers ──────────────────────────────
BODY_RE    = re.compile(r"(\{.*\})", re.DOTALL)
MESSAGE_RE = re.compile(r'"message"\s*:\s*"([^"]*)"')
CODE_RE    = re.compile(r"<code>\s*(\d{2,4})\s*</code>")
# Portal document URLs (…/p/… invoices, …/r/… receipts). Stop at quotes,
# whitespace, angle brackets or a trailing backslash from JSON-escaped XML.
URL_RE     = re.compile(r"https?://[^\s\"'<>\\]+")


def extract_portal_url(raw: str) -> str:
    """First portal document URL found in a failure message (the URL we append
    to each test message, or the downloadingInvoiceUrl echoed in a response).
    Prefers the demo-portal host; falls back to the first http(s) URL that is
    not a GitHub/schema link."""
    if not raw:
        return ""
    urls = URL_RE.findall(raw)
    for u in urls:
        if "einvoice-demo-portal" in u or "/p/" in u or "/r/" in u:
            return u.rstrip(".,)")
    for u in urls:
        if "github.com" not in u and "w3.org" not in u and "aade.gr" not in u:
            return u.rstrip(".,)")
    return ""


def extract_api_message(text: str) -> str:
    if not text:
        return ""
    for body_match in BODY_RE.finditer(text):
        body = body_match.group(1)
        try:
            data = json.loads(body)
            if isinstance(data, dict):
                if data.get("message"):
                    return str(data["message"])
                if data.get("error"):
                    return str(data["error"])
        except Exception:
            m = MESSAGE_RE.search(body)
            if m:
                return m.group(1)
    return ""


def short_message(raw: str, limit: int = 160) -> str:
    """Return the most useful one-line snippet from a Robot failure message."""
    if not raw:
        return ""
    api = extract_api_message(raw)
    if api:
        msg = api
    else:
        for line in raw.splitlines():
            line = line.strip()
            if line:
                msg = line.split(" | ")[0]
                break
        else:
            msg = raw.strip()
    msg = " ".join(msg.split())
    if len(msg) > limit:
        msg = msg[: limit - 1].rstrip() + "…"
    return msg


def _error_code(raw: str) -> str:
    m = CODE_RE.search(raw or "")
    return m.group(1) if m else ""


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


def soft_wrap(s: str, n: int = 20) -> str:
    """Insert zero-width break points into long unbroken tokens so Outlook
    can wrap them instead of widening the whole table."""
    out = []
    for tok in (s or "").split(" "):
        if len(tok) > n:
            tok = "​".join(tok[i:i + n] for i in range(0, len(tok), n))
        out.append(tok)
    return " ".join(out)


def safe(s: str) -> str:
    """esc + soft-wrap, ready to drop into a fixed-width cell."""
    return esc(soft_wrap(s))


# ────────────────────────── Robot output.xml model ───────────────────────
def collect_leaf_suites(root: ET.Element):
    for suite in root.iter("suite"):
        tests = suite.findall("test")
        if tests:
            yield suite.get("name") or "(unnamed)", tests


def test_status(t: ET.Element):
    st = t.find("status")
    status = st.get("status") if st is not None else ""
    elapsed = float(st.get("elapsed", 0)) if st is not None else 0.0
    raw = (st.text or "").strip() if st is not None else ""
    if not raw and st is not None:
        raw = (st.get("message") or "").strip()
    return status, elapsed, raw


def suite_description(name: str) -> str:
    low = name.lower()
    for key, desc in SUITE_INFO:
        if key in low:
            return desc
    return ""


# ────────────────────────── Grouping failures ────────────────────────────
def group_failures(failures):
    """Group same-suite failures that share the same short message."""
    out = []
    by_suite = {}
    for suite, name, msg in failures:
        by_suite.setdefault(suite, []).append((name, msg))

    for suite, items in by_suite.items():
        buckets = {}
        for name, msg in items:
            key = short_message(msg, limit=70)
            buckets.setdefault(key, []).append((name, msg))
        for _key, entries in buckets.items():
            names = [n for n, _ in entries]
            full_msg = entries[0][1]
            display_msg = short_message(full_msg, limit=180)
            code = _error_code(full_msg)
            # portal URL only makes sense for a single test (grouped tests
            # each have their own document)
            url = extract_portal_url(full_msg) if len(names) == 1 else ""
            if len(names) == 1:
                label = names[0]
            else:
                nums = []
                for n in names:
                    m = re.match(r"TC\s+0*(\d+)", n)
                    if m:
                        nums.append(int(m.group(1)))
                if nums and len(nums) == max(nums) - min(nums) + 1:
                    label = f"TC {min(nums):02d}–{max(nums):02d}  ({len(names)} tests)"
                else:
                    joined = ", ".join(names)
                    label = joined if len(joined) <= 70 else joined[:69] + "…"
            out.append((suite, label, display_msg, len(names), code, url))
    return out


# ────────────────────────── HTML components ───────────────────────────────
def stat_cell(label: str, value: str, w: int, bg: str, fg: str) -> str:
    return (
        f'<td width="{w}" valign="top" style="width:{w}px;padding:0 4px;">'
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"'
        f' style="border-collapse:collapse;"><tr>'
        f'<td bgcolor="{bg}" style="background:{bg};border-radius:8px;padding:12px 12px;">'
        f'<div style="font-family:{SANS};font-size:11px;line-height:14px;'
        f'color:{fg};opacity:0.8;">{label}</div>'
        f'<div style="font-family:{SANS};font-size:22px;line-height:28px;'
        f'font-weight:700;color:{fg};">{value}</div>'
        f"</td></tr></table></td>"
    )


def suite_row(name: str, passed: int, failed: int, skipped: int) -> str:
    total = passed + failed + skipped
    if failed:
        dot, cnt_color, cnt = C["fail_dot"], C["fail_text"], f"{failed} fail"
    elif skipped:
        dot, cnt_color, cnt = C["warn_dot"], C["warn_dot"], f"{skipped} skip"
    else:
        dot, cnt_color, cnt = C["ok_dot"], C["ok_text"], "OK"
    desc = suite_description(name)
    desc_html = (
        f'<div style="font-family:{SANS};font-size:11px;line-height:15px;'
        f'color:{C["faint"]};">{esc(desc)}</div>' if desc else ""
    )
    # widths: dot 16 | name 396 | count 140  = 552
    return (
        f'<tr>'
        f'<td width="16" valign="top" style="width:16px;padding:9px 0;">'
        f'<div style="width:9px;height:9px;border-radius:50%;background:{dot};'
        f'margin-top:4px;font-size:0;line-height:0;">&nbsp;</div></td>'
        f'<td width="396" valign="top" style="width:396px;padding:9px 8px;'
        f'border-bottom:1px solid {C["border2"]};">'
        f'<div style="font-family:{SANS};font-size:14px;line-height:18px;'
        f'font-weight:600;color:{C["text"]};">{esc(name)}</div>{desc_html}</td>'
        f'<td width="140" valign="top" align="left" style="width:140px;padding:9px 0;'
        f'border-bottom:1px solid {C["border2"]};font-family:{MONO};font-size:13px;'
        f'line-height:18px;color:{C["text"]};white-space:nowrap;">'
        f'{passed}/{total} &nbsp;'
        f'<span style="color:{cnt_color};font-weight:700;">{cnt}</span></td>'
        f"</tr>"
    )


def failure_block(suite: str, test_name: str, message: str,
                  count: int, code: str, url: str = "") -> str:
    pill = ""
    if count > 1:
        pill = (
            f'&nbsp;<span style="background:{C["fail_soft"]};color:{C["fail_dark"]};'
            f'font-family:{MONO};font-size:11px;padding:1px 6px;border-radius:4px;">'
            f'×{count}</span>'
        )
    hint = ERROR_HINTS.get(code, "")
    code_line = ""
    if code:
        code_txt = f"myDATA {code}" + (f" — {hint}" if hint else "")
        code_line = (
            f'<div style="font-family:{SANS};font-size:11px;line-height:15px;'
            f'color:{C["fail_dark"]};margin-top:6px;">'
            f'<b>{esc(code_txt)}</b></div>'
        )
    # Clickable portal link — short label, so the long URL never overflows.
    # href carries the full URL (escaped, NOT soft-wrapped so the link works).
    url_line = ""
    if url:
        url_line = (
            f'<div style="margin-top:6px;">'
            f'<a href="{esc(url)}" style="font-family:{SANS};font-size:12px;'
            f'font-weight:600;color:{C["accent"]};text-decoration:none;">'
            f'🔗 Άνοιγμα παραστατικού στο portal →</a></div>'
        )
    return (
        f'<table role="presentation" width="{CONTENT_W}" cellpadding="0" cellspacing="0"'
        f' border="0" style="width:{CONTENT_W}px;table-layout:fixed;border-collapse:collapse;'
        f'margin:0 0 8px 0;"><tr>'
        f'<td width="4" style="width:4px;background:{C["fail_dot"]};font-size:0;'
        f'line-height:0;">&nbsp;</td>'
        f'<td bgcolor="{C["fail_bg"]}" style="background:{C["fail_bg"]};padding:10px 12px;">'
        f'<div style="font-family:{SANS};font-size:13px;line-height:18px;'
        f'font-weight:600;color:{C["fail_dark"]};">'
        f'{esc(test_name)}{pill}</div>'
        f'<div style="font-family:{SANS};font-size:11px;line-height:15px;'
        f'color:{C["muted"]};margin:1px 0 6px 0;">{esc(suite)}</div>'
        f'<div style="font-family:{MONO};font-size:12px;line-height:17px;'
        f'color:{C["fail_text"]};word-break:break-all;">{safe(message)}</div>'
        f'{code_line}'
        f'{url_line}'
        f"</td></tr></table>"
    )


def section_title(text: str) -> str:
    return (
        f'<tr><td style="padding:20px {PAD_X}px 8px {PAD_X}px;">'
        f'<div style="font-family:{SANS};font-size:12px;line-height:16px;'
        f'letter-spacing:0.06em;text-transform:uppercase;color:{C["faint"]};'
        f'font-weight:700;border-bottom:2px solid {C["border"]};'
        f'padding-bottom:6px;">{esc(text)}</div></td></tr>'
    )


# ────────────────────────── Render ────────────────────────────────────────
def render(output_xml_path: str) -> str:
    root = ET.parse(output_xml_path).getroot()
    suites = list(collect_leaf_suites(root))

    total_pass = total_fail = total_skip = 0
    suite_summary = []
    failures = []
    total_ms = 0

    for suite_name, tests in suites:
        p = f = s = 0
        for t in tests:
            status, elapsed, raw = test_status(t)
            total_ms += int(elapsed * 1000)
            if status == "PASS":
                p += 1
            elif status == "FAIL":
                f += 1
                failures.append((suite_name, t.get("name") or "", raw))
            else:
                s += 1
        suite_summary.append((suite_name, p, f, s))
        total_pass += p
        total_fail += f
        total_skip += s

    total = total_pass + total_fail + total_skip
    pass_pct = round(100 * total_pass / total) if total else 0
    dur_s = total_ms / 1000.0
    duration = f"{dur_s:.0f}s" if dur_s < 60 else f"{int(dur_s // 60)}m {int(dur_s % 60):02d}s"

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    branch = os.environ.get("GITHUB_REF_NAME", "")
    run_url = f"{server}/{repo}/actions/runs/{run_id}" if repo and run_id else ""
    schedule = os.environ.get("RUN_SCHEDULE", "").strip()

    if total_fail:
        status_label, status_bg, status_fg = f"{total_fail} FAILED", C["fail_bg"], C["fail_text"]
    elif total_skip:
        status_label, status_bg, status_fg = "PASSED (with skips)", C["warn_bg"], C["warn_dot"]
    else:
        status_label, status_bg, status_fg = "ALL PASSED", C["ok_bg"], C["ok_text"]

    header_title = f"Run #{run_id}" if run_id else "Test run summary"
    if branch:
        header_title += f" · {branch}"

    schedule_html = ""
    if schedule:
        schedule_html = (
            f'<div style="font-family:{SANS};font-size:11px;line-height:15px;'
            f'color:{C["faint"]};margin-top:3px;">🕒 Τρέχει {esc(schedule)}</div>'
        )

    # Stat row (4 × 138 = 552)
    stats = (
        stat_cell("Pass rate", f"{pass_pct}%", 138, C["accent_bg"], C["accent"])
        + stat_cell("Total", str(total), 138, C["bg"], C["text"])
        + stat_cell("Passed", str(total_pass), 138, C["ok_bg"], C["ok_text"])
        + stat_cell("Failed", str(total_fail), 138, C["fail_bg"], C["fail_dark"])
    )

    suite_rows = "".join(
        suite_row(n, p, f, s) for n, p, f, s in suite_summary
    )

    grouped = group_failures(failures)
    failures_section = ""
    if grouped:
        blocks = "".join(
            failure_block(su, nm, msg, cnt, code, url)
            for su, nm, msg, cnt, code, url in grouped
        )
        failures_section = (
            section_title(f"Αστοχίες ({total_fail})")
            + f'<tr><td style="padding:4px {PAD_X}px 4px {PAD_X}px;">{blocks}</td></tr>'
        )

    run_link = (
        f'<a href="{run_url}" style="color:{C["accent"]};text-decoration:none;'
        f'font-weight:600;">Άνοιγμα run στο GitHub →</a>' if run_url else ""
    )

    return f"""\
<!DOCTYPE html>
<html xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>API regression report</title>
<!--[if mso]>
<style type="text/css">table,td,div,p,a{{font-family:Segoe UI,Arial,sans-serif !important;}}</style>
<![endif]-->
</head>
<body style="margin:0;padding:0;background:{C['bg']};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
 style="background:{C['bg']};border-collapse:collapse;"><tr>
<td align="center" style="padding:20px 10px;">

<!--[if mso]><table role="presentation" width="{EMAIL_W}" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" width="{EMAIL_W}" cellpadding="0" cellspacing="0" border="0"
 bgcolor="{C['card']}" style="width:{EMAIL_W}px;max-width:{EMAIL_W}px;background:{C['card']};
 border:1px solid {C['border']};border-radius:10px;border-collapse:separate;table-layout:fixed;">

<!-- Header -->
<tr><td style="padding:20px {PAD_X}px 16px {PAD_X}px;border-bottom:1px solid {C['border']};">
  <table role="presentation" width="{CONTENT_W}" cellpadding="0" cellspacing="0" border="0"
   style="width:{CONTENT_W}px;table-layout:fixed;border-collapse:collapse;"><tr>
    <td width="360" valign="middle" style="width:360px;">
      <div style="font-family:{SANS};font-size:12px;line-height:16px;color:{C['muted']};">
        API Regression · einvoice UAT</div>
      <div style="font-family:{SANS};font-size:19px;line-height:24px;font-weight:700;
        color:{C['text']};">{esc(header_title)}</div>
      {schedule_html}
    </td>
    <td width="192" valign="middle" align="left" style="width:192px;padding-left:8px;">
      <span style="display:inline-block;background:{status_bg};color:{status_fg};
        font-family:{SANS};font-size:12px;font-weight:700;padding:6px 12px;
        border-radius:6px;white-space:nowrap;">{esc(status_label)}</span>
    </td>
  </tr></table>
</td></tr>

<!-- Stats -->
<tr><td style="padding:16px {PAD_X}px 4px {PAD_X}px;">
  <table role="presentation" width="{CONTENT_W}" cellpadding="0" cellspacing="0" border="0"
   style="width:{CONTENT_W}px;table-layout:fixed;border-collapse:collapse;">
   <tr>{stats}</tr></table>
</td></tr>

<!-- Suites -->
{section_title("Suites")}
<tr><td style="padding:0 {PAD_X}px 8px {PAD_X}px;">
  <table role="presentation" width="{CONTENT_W}" cellpadding="0" cellspacing="0" border="0"
   style="width:{CONTENT_W}px;table-layout:fixed;border-collapse:collapse;">
   {suite_rows}</table>
</td></tr>

{failures_section}

<!-- Footer -->
<tr><td style="padding:14px {PAD_X}px 18px {PAD_X}px;border-top:1px solid {C['border']};">
  <table role="presentation" width="{CONTENT_W}" cellpadding="0" cellspacing="0" border="0"
   style="width:{CONTENT_W}px;table-layout:fixed;border-collapse:collapse;"><tr>
    <td width="200" valign="middle" style="width:200px;font-family:{SANS};font-size:12px;
      color:{C['muted']};">Διάρκεια {duration}</td>
    <td width="352" valign="middle" align="left" style="width:352px;font-family:{SANS};
      font-size:13px;">{run_link}</td>
  </tr></table>
</td></tr>

</table>
<!--[if mso]></td></tr></table><![endif]-->

</td></tr></table>
</body></html>
"""


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: build_email_html.py <combined/output.xml> <email_body.html>",
              file=sys.stderr)
        return 2
    inp, out = sys.argv[1], sys.argv[2]
    if not os.path.exists(inp):
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(
                "<html><body style='font-family:sans-serif;padding:24px;'>"
                "<h2>API regression report</h2>"
                "<p>No combined output.xml produced. All suites probably failed "
                "before producing results.</p></body></html>"
            )
        return 0
    html = render(inp)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html)
    return 0


if __name__ == "__main__":
    sys.exit(main())
