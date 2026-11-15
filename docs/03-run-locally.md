# 3. Prepare the data and run the script locally

[← 2. Authorize your org](02-authorize-org.md) · Next: [4. Package and deploy →](04-package-and-deploy.md)

## The use case

Vaccination records arrive as XML, one **clinic batch** per row, in a text field of a source DLO:

```xml
<ClinicBatch batchId="BATCH-NORTH-2024">
  <Patient>
    <PatientId>P-1001</PatientId>
    <Name>…</Name>
    <DateOfBirth>1955-04-18</DateOfBirth>
    <Vaccinations>
      <Vaccination><Vaccine>Influenza</Vaccine><Date>2024-10-05</Date></Vaccination>
      <Vaccination><Vaccine>Shingrix</Vaccine><Date>2023-06-01</Date></Vaccination>
    </Vaccinations>
  </Patient>
  <Patient>…</Patient>
</ClinicBatch>
```

[`payload/entrypoint.py`](../patient-xml-transform/payload/entrypoint.py) reads every batch and parses the XML with Python's standard `xml.etree`. It writes **one row per `<Patient>`** to a target DLO and derives these fields:

| Target field | How it's derived |
|---|---|
| `patient_id__c` | `<PatientId>` |
| `name__c` | `<Name>` |
| `age__c` | Whole years from `<DateOfBirth>` to today |
| `vaccines_received__c` | Every `<Vaccine>`, standardized (typo fixes, title case) and comma-separated |
| `most_recent_vaccination_date__c` | Latest `<Date>` (several date formats accepted) |
| `has_covid_vaccine__c` | `Yes` if any vaccine name contains "covid", otherwise `No` |

The sample file [`data/patients_raw_xml.csv`](../patient-xml-transform/data/patients_raw_xml.csv) has **4 batches** with **12 patients** in total. All of the data is fictional.

Official reference: [Create Data Lake Objects](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/create-dlos.html).

---

## Step 1: Load the sample data (source DLO)

1. In Data 360, open **Data Streams → New** and choose **File Upload** as the source.
2. Upload `patient-xml-transform/data/patients_raw_xml.csv`.
3. Confirm that both columns are detected as **Text**: `RecordId` and `RawXml`.
4. Set **`RecordId`** as the **Primary Key**. We used the category **Profile**.
5. Name the Data Lake Object **`Patients_Raw_XML`**. Data 360 adds the suffix, so its API name becomes **`Patients_Raw_XML__dll`**.
6. Choose the **`default`** data space and deploy the stream.

The resulting DLO has these fields. The script reads them in lowercase.

| Field (as shown in the UI) | Name in code | Type |
|---|---|---|
| `RecordId__c` | `recordid__c` | Text (Primary Key) |
| `RawXml__c` | `rawxml__c` | Text |

## Step 2: Create the target DLO

Go to **Data Lake Objects → New** and create a DLO from scratch:

- **Object label:** `Patients Enriched`. **API name:** `Patients_Enriched`, which becomes `Patients_Enriched__dll`.
- **Category:** Other.
- **Fields:** create them exactly as below, including the types. Data 360 adds `__c` to each API name.

| Field API name | Type | Notes |
|---|---|---|
| `patient_id` | **Text** | **Primary Key** |
| `name` | **Text** | Must be Text, not Number. See the warning below |
| `age` | **Number** | |
| `vaccines_received` | **Text** | |
| `most_recent_vaccination_date` | **Date** | |
| `has_covid_vaccine` | **Text** | |

Then add the DLO to the data space: **Data Spaces → default → Add Data Lake Objects → `Patients_Enriched__dll`**. The source DLO is already in `default` because you chose it in the data stream.

> ⚠️ **Field types matter, and the local run won't catch a wrong one.** The local run checks that every column the script writes exists in the target DLO, but **not** that the types match. If `name` is created as **Number**, the local run succeeds and the deployed transform fails later with `CANNOT_SAFELY_CAST`. You can't change a field's type after the DLO is created. Get it right now, or recreate the DLO.

> **Governance:** if your org uses data governance tags, assign them to `Patients_Enriched__dll` **manually**. Tags aren't yet propagated automatically from source to target objects.

> **You may face:** a field you created as `name` appears as `name__c`. That's expected, because DLO custom fields get the `__c` suffix. The script writes `name__c`.

## Step 3: What was wrong in the original kit

This lab started from an internal demo kit that didn't run as published. Here's what we changed and why. Each item is a pattern you'll meet again in your own Code Extensions.

| What | Original | Fixed | Why it matters |
|---|---|---|---|
| Column name in `entrypoint.py` | `df.select("RawXml__c")` | `df.select("rawxml__c")` | The SDK exposes DLO columns in **lowercase**. Mixed case fails with `Column 'RawXml__c' not found. Did you mean 'rawxml__c'? Data Cloud columns must be lowercase.` Always use lowercase in code, whatever the UI shows. |
| `sdkVersion` in `config.json` | `6.1.0` | `7.0.0` | Matches the SDK this lab installs. |
| Local run flag | `--config ./payload/config.json` | `--config-file ./payload/config.json`, or omit it | `--config` doesn't exist: `Nonexistent flag: --config`. |
| Local run org | No `--target-org` | `--target-org byoc-org` | It's a required flag, and without it the CLI's default org is used. |
| Target DLO setup | "add it to your dataspace" in passing | An explicit step, plus a type table | If the DLO isn't in `default`, every read **and** the local write check fail with `table "Patients_Enriched__dll" does not exist`. A missing field, or a Number `name`, fails later. |

The parsing logic itself didn't change.

## Step 4: Run the script locally

Enter the environment first ([Setup, Part B](01-setup.md#part-b-every-new-terminal)), then run the script from the **package folder**.

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

- It runs your script in **Spark on your laptop**, reading **real data** from your org through the Data 360 Query API.
- `write_to_dlo` **doesn't write** to Data 360. Locally, the SDK uses a *print* writer, which checks that your columns exist in the target DLO and then prints the DataFrame (`dataframe.show()`). This is the table above.
- So **`Patients_Enriched__dll` stays empty** after a local run. You can confirm that in **Query Editor** with `SELECT COUNT(*) FROM "Patients_Enriched__dll";`, which returns `0`. It fills when the deployed transform runs ([step 4](04-package-and-deploy.md)).
- Local reads return **at most 1,000 rows** by default. That's plenty for this lab. For bigger tests, the docs show how to raise `default_row_limit`, and you must reset it before packaging.
- The printed table is local console output only. It doesn't go to the Data 360 logs DLO.

Official reference: [Write and Validate Custom Scripts](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/author-custom-script.html).

## Known challenges

> **You may face:** `Error (2): Nonexistent flag: --config`. The flag is `--config-file`. It's optional and defaults to `payload/config.json`.
>
> **You may face:** `Missing required flag target-org`, or the run silently uses another org. `--target-org` (`-o`) is required. Always pass `-o byoc-org`.
>
> **You may face:** `RuntimeError: Data Cloud query failed (HTTP 400): … table "Patients_Enriched__dll" does not exist`, even though you can see the DLO in the UI. Check two things. (1) The DLO isn't in the **`default`** data space: open it, and if **Data Mapping** says it isn't in a data space, add it (Step 2). (2) You're pointing at a **different org**: run `sf org display -o byoc-org` and compare the Instance URL with your browser. The same error for `Patients_Raw_XML__dll` means the same thing for the source.
>
> **You may face:** `ValueError: The following columns are not present in the DLO 'Patients_Enriched__dll': ['age__c']`. The target DLO is missing a field the script writes. Add the field, or recreate the DLO with all six fields (Step 2).
>
> **You may face:** `Column 'RawXml__c' not found. Did you mean 'rawxml__c'? Data Cloud columns must be lowercase.` Code must use lowercase column names. The DLO's field is `RawXml__c` in the UI, but in code it's `rawxml__c`.
>
> **You may face:** `[JAVA_GATEWAY_EXITED] Java gateway process exited before sending its port number`, or `spark-class: … CMD: bad array subscript`. Spark couldn't start a JVM because Java 17 isn't on `JAVA_HOME`. Run `source ./env.sh` (or `. .\env.ps1`) in this terminal. See [Setup, Step 7](01-setup.md#step-7-java-17-azul-zulu).
>
> **You may face:** `PythonVersionMismatch`, or `PackageNotInstalled` for `salesforce-data-customcode`. The venv isn't active in this terminal, or it has no pip. See [Setup, Step 5](01-setup.md#step-5-clone-the-lab-and-create-the-python-311-environment).
>
> **You may face:** `ModuleNotFoundError` for a package your script imports. `--dependencies` won't help: it takes comma-separated **import** names (`yaml`, not `pyyaml`) and **installs nothing**. Each module must already be installed in the venv (`uv pip install <package>`). This lab's script needs no extra packages.
>
> **You may face:** the error output suggests `Run 'sf data-code-extension <type> scan'`, and running it in zsh gives `no such file or directory: type`. `<type>` is a placeholder, and the shell reads `<` as a redirect. The real command is `sf data-code-extension script scan --entrypoint ./payload/entrypoint.py`.
>
> **You may face:** `WARN NativeCodeLoader: Unable to load native-hadoop library for your platform`. This is harmless. Local Spark falls back to built-in Java classes.

---

[← 2. Authorize your org](02-authorize-org.md) · Next: [4. Package and deploy →](04-package-and-deploy.md)
