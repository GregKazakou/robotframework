# einvoice API Regression Tests

Automated API regression suite for **einvoice UAT**, written in [Robot Framework](https://robotframework.org/). Runs twice daily on GitHub Actions and emails an HTML report.

## Layout

```
Automation/                       # Robot test suites + JSON templates
  ├── FNB_flows.robot                  (TC 01 – TC 16)
  ├── FNB_InternalID_Cases.robot       (TC 01 – TC 07)
  ├── POS_flows.robot                  (TC 01 – TC 05)
  ├── Receipts_InternalID_Cases.robot  (TC 01 – TC 07)
  ├── DN Life Cycle.robot              (TC 01 – TC 40)  # Ψηφιακή Διακίνηση Αποθεμάτων Β΄ Φάση
  └── dateIssued_matrix.robot          (TC 01 – TC 32)  # dateIssued GR-timezone matrix (8.4/8.6/11.1/1.1)
config/
  ├── credentials.py             # ❌ local only — never committed
  └── credentials.example.py     # ✅ template for new devs
scripts/build_email_html.py      # Generates HTML email from output.xml
.github/workflows/api-tests.yml  # CI workflow
```

All test cases follow `TC NN - <description>` with zero-padded numbering, restarting per suite.

## Local setup

```bash
pip install -r requirements.txt
cp config/credentials.example.py config/credentials.py
# edit config/credentials.py with your real API key
robot --outputdir results Automation/
```

`config/credentials.py` is gitignored — never commit it.

**PyCharm:** Just hit ▶️ on a `.robot` file. No env vars or scripts needed since `credentials.py` exists locally.

### DN Life Cycle suite

`DN Life Cycle.robot` covers the 40 Delivery-Note lifecycle scenarios from the ΣΕΠΕ v4 guidance
(Ψηφιακή Παρακολούθηση Διακίνησης Αποθεμάτων, Β΄ Φάση). It needs the extra `DN_*` variables added to
`config/credentials.example.py` (provider API keys + AADE `aade-user-id`/`subscription-key` per role).

- Create via the Provider API; `RegisterTransfer` / `ConfirmDeliveryOutcome` / `RejectDeliveryNote` /
  `GetDeliveryNoteStatus` via AADE myDATA dev.
- `ConfirmDeliveryReturn` and `RegisterTransfer–Return` are **placeholders** (not yet in the official API).
  Tests that use them carry `[Tags] placeholder`:

  ```bash
  robot --exclude placeholder --outputdir results "Automation/DN Life Cycle.robot"
  ```

- Status assertions default to lenient (mismatches → warnings). Set `${STRICT_STATUS}=${True}` to enforce
  once the exact status vocabulary is confirmed.

## How credentials work

The same `.robot` files run identically locally and in CI. Both read from `config/credentials.py` via:

```robotframework
Variables    ${EXECDIR}/config/credentials.py
```

| Environment | Where `credentials.py` comes from |
|-------------|-----------------------------------|
| Local | You create it once from the example file |
| CI | Workflow recreates it at runtime from `${{ secrets.EINVOICE_API_KEY }}` |

## CI / GitHub Actions

Triggers: **schedule** (06:00 + 14:00 UTC), **manual** (Actions tab → Run workflow).

Pipeline: `discover` → `test` (4 suites in parallel, `fail-fast: false`) → `report` (rebot merge → HTML email + artifacts).

### Required GitHub Secrets

Set in **Settings → Secrets and variables → Actions**:

| Secret | What it is |
|--------|-----------|
| `EINVOICE_API_KEY` | UAT API key |
| `EMAIL_USERNAME` | Gmail address sending the report |
| `EMAIL_PASSWORD` | Gmail [App Password](https://support.google.com/accounts/answer/185833) |

## Adding a new suite

1. Drop your `.robot` file in `Automation/`
2. Add its path to the `SUITES` env var in `.github/workflows/api-tests.yml`
3. Use `TC NN - description` naming
4. Push

## Troubleshooting

- **`Variable file '...credentials.py' does not exist`** → run `cp config/credentials.example.py config/credentials.py` and fill it in
- **Tests pass locally but fail in CI** → check `EINVOICE_API_KEY` secret in GitHub Settings
- **Email not arriving** → verify `EMAIL_PASSWORD` is a Gmail App Password, not the account password

## Stack

Robot Framework · RequestsLibrary · GitHub Actions · [dawidd6/action-send-mail](https://github.com/dawidd6/action-send-mail)
