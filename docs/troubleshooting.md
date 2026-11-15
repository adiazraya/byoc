# Troubleshooting

[← README](../README.md)

Every error we hit while building this lab, grouped by stage. Before anything else, run the preflight from the repository root: `./verify.sh byoc-org` (macOS) or `.\verify.ps1 -OrgAlias byoc-org` (Windows). It checks most of the setup rows below automatically.

## Setup ([01-setup.md](01-setup.md))

| Symptom | Cause | Fix |
|---|---|---|
| `@salesforce/cli update available from X to Y` | Informational | Ignore. Any CLI version from 2.130.9 works |
| `sf` not recognized right after installing (Windows) | `PATH` only updates in new terminals | Open a new terminal |
| `data-code-extension … is not a sf command` | Plugin not installed | `sf plugins install @salesforce/plugin-data-code-extension` ([Step 3](01-setup.md#step-3-code-extension-plugin)) |
| `ETARGET … No matching version found … with a date before …` | npm minimum-release-age policy | Pin an older plugin version ([Step 3](01-setup.md#step-3-code-extension-plugin)) |
| `npm: command not found` (macOS) | Partial Node install | Ignore. `sf` bundles its own npm |
| `PythonVersionMismatch … exactly version 3.11 is required` | venv not active; the system `python3` is a different version | `source ./env.sh` / `. .\env.ps1` |
| `PackageNotInstalled: … 'salesforce-data-customcode'` although `uv pip show` finds it | venv created without pip; the plugin checks with `pip` | `uv pip install pip`, or recreate it with `uv venv --python 3.11 --seed .venv` |
| `Activate.ps1 cannot be loaded because running scripts is disabled` | PowerShell execution policy | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
| `python3` opens the Microsoft Store (Windows) | App execution aliases | Disable the `python.exe`/`python3.exe` aliases in Settings |
| `CMD: bad array subscript` / `JAVA_GATEWAY_EXITED` | No Java 17, or `JAVA_HOME` not set | Install Zulu 17, then `source ./env.sh` ([Step 7](01-setup.md#step-7-java-17-azul-zulu)) |
| `Did not find winutils.exe` / `HADOOP_HOME … unset` (Windows) | Local Spark looks for Hadoop helpers | Usually harmless ([Step 7](01-setup.md#step-7-java-17-azul-zulu)) |
| `Python worker failed to connect back` (Windows) | Spark started the wrong Python | Set `PYSPARK_PYTHON` (`. .\env.ps1` does it) |
| `Run this with 'source ./env.sh'` / `Dot-source this script` | Env script executed instead of sourced | `source ./env.sh` / `. .\env.ps1` |

## Org authorization ([02-authorize-org.md](02-authorize-org.md))

| Symptom | Cause | Fix |
|---|---|---|
| The browser authorizes the wrong org | Existing browser session | Log out first, or use `--browser chrome` with a private window |
| Login page loops / invalid domain | Org enforces My Domain login | `--instance-url https://<yourdomain>.my.salesforce.com` |
| `localhost refused to connect` after **Allow** | Callback port 1717 blocked (VPN, firewall, another process) | Disconnect the VPN or free the port. Without a browser, use `sf org login sfdx-url` |
| `No authorization information found for byoc-org` | Alias never created, or session expired | `sf org login web --alias byoc-org` |
| `InvalidProjectWorkspaceError` on `sf config set target-org` | The lab folder isn't an SFDX project | Don't use `--global`. Pass `-o byoc-org` on every command |
| `401` / `403` / `INSUFFICIENT_ACCESS` on run | Missing permission set, or Data 360 not available to the user | Assign Data Cloud Architect; check Feature Manager |

## Local run ([03-run-locally.md](03-run-locally.md))

| Symptom | Cause | Fix |
|---|---|---|
| `Nonexistent flag: --config` | Wrong flag name | `--config-file` (optional; defaults to `payload/config.json`) |
| `Missing required flag target-org` | `--target-org` is required | Add `-o byoc-org` |
| `Column 'RawXml__c' not found. Did you mean 'rawxml__c'?` | Code uses mixed-case column names | Use lowercase in code: `rawxml__c` |
| `table "Patients_Enriched__dll" does not exist` (DLO visible in the UI) | DLO not in the `default` data space, or the command targets a different org | Add the DLO to `default`; check `sf org display -o byoc-org` against the browser |
| `columns are not present in the DLO … ['age__c']` | Target DLO missing a field | Add the field, or recreate the DLO with all six fields |
| `ModuleNotFoundError` | Package not installed in the venv. `--dependencies` installs nothing | `uv pip install <pkg>`; add it to `requirements.txt` |
| `zsh: no such file or directory: type` | Ran the hint `sf data-code-extension <type> scan` literally | `sf data-code-extension script scan --entrypoint ./payload/entrypoint.py` |
| `WARN NativeCodeLoader: Unable to load native-hadoop library` | Local Spark has no native Hadoop | Harmless |
| Target DLO still empty after a successful local run | Expected: the local writer only validates columns and prints | Deploy and run the transform ([04](04-package-and-deploy.md)) |

## Scan, zip and deploy ([04-package-and-deploy.md](04-package-and-deploy.md))

| Symptom | Cause | Fix |
|---|---|---|
| `PipreqsScanError: Failed to scan imports using pipreqs` | `pipreqs` not in the venv | `uv pip install pipreqs`, or `scan --no-requirements` |
| `dataspace must be defined` | `dataspace` key missing from `config.json` | Add `"dataspace": "default"` |
| `[CdpCustomCodeDeployment]` feature not enabled | Code Extension off in Feature Manager | Enable it and deploy again |
| `DeploymentExists … Please use a different name` | Name already used. `--package-version` doesn't update a deployment | Deploy as `…_v2`, or delete the old transform and deployment first |
| `DeploymentExists` after a deploy failed halfway | The deployment record is created before zip and upload | Fix the cause, then delete the record or use a new name |
| `returned no file upload URL` | User or org can't create deployments | Check the permission set and Feature Manager |
| Many `Deployment status: Initializing` lines | Normal. The CLI polls every second | Wait. A few minutes is typical |
| Deployment shows `computeType: CPU_XS` in the API although you passed `CPU_L` | Internal naming | Expected |

## Deployed run (Run History / logs)

| Symptom | Cause | Fix |
|---|---|---|
| `CANNOT_SAFELY_CAST … 'name__c' "STRING" to "DECIMAL(38,18)"` | Target field created with the wrong type (Number instead of Text). Local runs don't check types | Delete the transform, recreate the DLO with the right types, recreate the transform ([04](04-package-and-deploy.md#errors-you-may-hit-in-the-deployed-run)) |
| Traceback spread over many rows of `^` | One log row per output line | Look at the `Failed to startup:` row (`queries/errors-only.json`) |
| `SDK config file not found at /mnt/customer-code/…` (DEBUG) | Informational | Harmless |
| Run succeeded, target looks empty | Wrong data space in Query Editor, or queried too early | Select `default`; query after `Success` |
| Code Extension won't delete | A data transform still references it | Delete the transform first |

## Still stuck?

- Rerun the failing command with a clean environment: open a new terminal, `source ./env.sh`, then `./verify.sh byoc-org`.
- Read the full error. The plugin's `Try this:` hints are generic, and the real cause is usually in the lines above them.
- Official docs: [Code Extension in Data 360](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/use-custom-code.html) · [CLI plugin issues](https://github.com/salesforcecli/plugin-data-code-extension) · [SDK issues](https://github.com/forcedotcom/datacloud-customcode-python-sdk)
