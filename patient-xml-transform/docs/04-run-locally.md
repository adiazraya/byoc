# 4. Run the script locally

**Use case 1: Patient vaccination XML** · [All use cases](../../README.md#part-2-use-cases)

[← 3. Prepare the data](03-prepare-data.md) · Next: [5. Package and deploy →](05-package-and-deploy.md)

> **Labels:** 🔧 **Technical** = the same for any Code Extension. 🩺 **Use case** = specific to the patient-XML example. See [step 3](03-prepare-data.md) for the full legend.

You'll run the script on your laptop against the real data in your org. This catches code and setup problems in seconds, before you package or deploy anything.

**Before you start:** both DLOs exist, are in the `default` data space and pass the [check at the end of step 3](03-prepare-data.md#check-before-you-continue).

## Step 1: Know what the script does

The script has a technical skeleton, which you reuse, and use-case logic, which you replace. This table separates them:

| Part of [`entrypoint.py`](../payload/entrypoint.py) | What it does | Label |
|---|---|---|
| `SOURCE_DLO`, `TARGET_DLO` constants | Names the DLOs to read and write. `scan` reads them to build `config.json` permissions | 🔧 pattern, 🩺 names |
| `Client()` and `client.read_dlo(SOURCE_DLO)` | Opens the SDK client and reads the source DLO as a Spark DataFrame | 🔧 |
| `VACCINE_CORRECTIONS`, `standardize_vaccine_name()`, `compute_age()` | Cleans vaccine names and derives age | 🩺 |
| `parse_patients()` | Parses one XML blob into one flat dict per `<Patient>` | 🩺 |
| `df.select("rawxml__c").collect()` and the loop | Reads the column in **lowercase** and processes each row in plain Python on the driver | 🔧 pattern, 🩺 column |
| `StructType([...])` and `spark.createDataFrame(...)` | Builds a DataFrame whose columns and types match the target DLO | 🔧 pattern, 🩺 fields |
| `to_date(col(...), "yyyy-MM-dd")` | Converts the date text to a real Date for the Date field | 🩺 |
| `client.write_to_dlo(TARGET_DLO, df, write_mode=WriteMode.OVERWRITE)` | Writes the result. `OVERWRITE` replaces the target's contents on each run | 🔧 |

For your own example, keep the 🔧 lines, and replace the 🩺 ones with your own logic and fields.

## Step 2: Run the script locally

🔧 **Technical:** the same for any Code Extension.

Enter the environment first ([Setup, Part B](../../docs/01-setup.md#part-b-every-new-terminal)), then run the script from the **package folder**. Everything in this step is the same for any Code Extension: only the entrypoint path changes.

macOS:

```bash
cd byoc && source ./env.sh
cd patient-xml-transform

sf data-code-extension script run \
  --entrypoint ./payload/entrypoint.py \
  --config-file ./payload/config.json \
  --target-org byoc-org
```

Windows:

```powershell
cd byoc; . .\env.ps1
cd patient-xml-transform

sf data-code-extension script run `
  --entrypoint .\payload\entrypoint.py `
  --config-file .\payload\config.json `
  --target-org byoc-org
```

On Windows, the backtick `` ` `` must be the **last** character on each line, so you may prefer to put the whole command on one line. `--config-file` is optional, because it defaults to `payload/config.json`.

Expected output:

```
Checking Python version...... done
Python 3.11.x found at 'python3'
Checking required Python packages...... done
Package 'salesforce-data-customcode' version 7.0.0 found
Authenticating with Salesforce org '<your user>'...... done
Running package against Salesforce org...
+-------------+--------+------+--------------------+-------------------------------+--------------------+
|patient_id__c| name__c|age__c|vaccines_received__c|most_recent_vaccination_date__c|has_covid_vaccine__c|
+-------------+--------+------+--------------------+-------------------------------+--------------------+
|       P-1001|     ...|   ...| Influenza, Shingrix|                     2024-10-05|                  No|
|       P-1002|     ...|   ...|Covid-19 (Comirna...|                     2024-09-20|                 Yes|
|          ...|        |      |                    |                               |                    |
|       P-1012|     ...|   ...|                Tdap|                     2020-02-02|                  No|
+-------------+--------+------+--------------------+-------------------------------+--------------------+
Package at './payload/entrypoint.py' executed successfully!
Data Code Extension run completed successfully!
```

You should see **12 rows**, P-1001 to P-1012. `age__c` depends on today's date.

## What a local run does, and doesn't do

🔧 **Technical:** the same for any Code Extension.

- It runs your script in **Spark on your laptop**, reading **real data** from your org through the Data 360 Query API.
- `write_to_dlo` **doesn't write** to Data 360. Locally, the SDK uses a *print* writer, which checks that your columns exist in the target DLO and then prints the DataFrame (`dataframe.show()`). This is the table above.
- So **`Patients_Enriched__dll` stays empty** after a local run. You can confirm that in **Query Editor** with `SELECT COUNT(*) FROM "Patients_Enriched__dll";`, which returns `0`. It fills when the deployed transform runs ([step 5](05-package-and-deploy.md)).
- Local reads return **at most 1,000 rows** by default. That's plenty for this lab. For bigger tests, the docs show how to raise `default_row_limit`, and you must reset it before packaging.
- The printed table is local console output only. It doesn't go to the Data 360 logs DLO.

Official reference: [Write and Validate Custom Scripts](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/author-custom-script.html).

## Lessons from the original kit

🔧 **Technical:** the same for any Code Extension.

This lab started from a demo kit that didn't run as published. Here's what we changed and why. Each item is a technical pattern you'll meet again in your own Code Extensions.

| What | Original | Fixed | Why it matters |
|---|---|---|---|
| Column name in `entrypoint.py` | `df.select("RawXml__c")` | `df.select("rawxml__c")` | The SDK exposes DLO columns in **lowercase**. Mixed case fails with `Column 'RawXml__c' not found. Did you mean 'rawxml__c'? Data Cloud columns must be lowercase.` Always use lowercase in code, whatever the UI shows. |
| `sdkVersion` in `config.json` | `6.1.0` | `7.0.0` | Matches the SDK this lab installs. |
| Local run flag | `--config ./payload/config.json` | `--config-file ./payload/config.json`, or omit it | `--config` doesn't exist: `Nonexistent flag: --config`. |
| Local run org | No `--target-org` | `--target-org byoc-org` | It's a required flag, and without it the CLI's default org is used. |
| Target DLO setup | "add it to your dataspace" in passing | An explicit step, plus a type table | If the DLO isn't in `default`, every read **and** the local write check fail with `table "Patients_Enriched__dll" does not exist`. A missing field, or a Number `name`, fails later. |

The parsing logic itself (🩺 use case) didn't change.

## Known challenges

🔧 **Technical:** the same for any Code Extension.

> **You may face:** `Error (2): Nonexistent flag: --config`. The flag is `--config-file`. It's optional and defaults to `payload/config.json`.
>
> **You may face:** `Missing required flag target-org`, or the run silently uses another org. `--target-org` (`-o`) is required. Always pass `-o byoc-org`.
>
> **You may face:** `RuntimeError: Data Cloud query failed (HTTP 400): … table "Patients_Enriched__dll" does not exist`, even though you can see the DLO in the UI. Check two things. (1) The DLO isn't in the **`default`** data space: open it, and if **Data Mapping** says it isn't in a data space, add it ([step 3](03-prepare-data.md#step-2-create-the-target-dlo)). (2) You're pointing at a **different org**: run `sf org display -o byoc-org` and compare the Instance URL with your browser. The same error for `Patients_Raw_XML__dll` means the same thing for the source.
>
> **You may face:** `ValueError: The following columns are not present in the DLO 'Patients_Enriched__dll': ['age__c']`. The target DLO is missing a field the script writes. Add the field, or recreate the DLO with all six fields ([step 3](03-prepare-data.md#step-2-create-the-target-dlo)).
>
> **You may face:** `Column 'RawXml__c' not found. Did you mean 'rawxml__c'? Data Cloud columns must be lowercase.` Code must use lowercase column names. The DLO's field is `RawXml__c` in the UI, but in code it's `rawxml__c`.
>
> **You may face:** `[JAVA_GATEWAY_EXITED] Java gateway process exited before sending its port number`, or `spark-class: … CMD: bad array subscript`. Spark couldn't start a JVM because Java 17 isn't on `JAVA_HOME`. Run `source ./env.sh` (or `. .\env.ps1`) in this terminal. See [Setup, Step 7](../../docs/01-setup.md#step-7-java-17-azul-zulu).
>
> **You may face:** `PythonVersionMismatch`, or `PackageNotInstalled` for `salesforce-data-customcode`. The venv isn't active in this terminal, or it has no pip. See [Setup, Step 5](../../docs/01-setup.md#step-5-clone-the-lab-and-create-the-python-311-environment).
>
> **You may face:** `ModuleNotFoundError` for a package your script imports. `--dependencies` won't help: it takes comma-separated **import** names (`yaml`, not `pyyaml`) and **installs nothing**. Each module must already be installed in the venv (`uv pip install <package>`). This lab's script needs no extra packages.
>
> **You may face:** the error output suggests `Run 'sf data-code-extension <type> scan'`, and running it in zsh gives `no such file or directory: type`. `<type>` is a placeholder, and the shell reads `<` as a redirect. The real command is `sf data-code-extension script scan --entrypoint ./payload/entrypoint.py`.
>
> **You may face:** `WARN NativeCodeLoader: Unable to load native-hadoop library for your platform`. This is harmless. Local Spark falls back to built-in Java classes.

---

[← 3. Prepare the data](03-prepare-data.md) · Next: [5. Package and deploy →](05-package-and-deploy.md)
