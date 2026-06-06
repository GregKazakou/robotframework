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

