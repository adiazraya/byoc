# Bring Your Own Code: Data 360 Code Extension hands-on lab

Run your own Python code **inside Data 360**. Read data from a Data Lake Object, transform it with logic you write, and write the result to another Data Lake Object.

This repository has two parts:

1. **General introduction (common to every use case).** What Code Extension is, how it works, and the one-time setup of your laptop and org.
2. **Use cases.** Each use case is a complete, hands-on example with its own business problem, sample data, architecture, code and steps. **The first one is the patient vaccination XML transform.** More use cases will follow, each with its own architecture.

```
                    ┌──────────────────────────────────────────────┐
                    │  Part 1: General introduction (do it once)   │
                    │  What Code Extension is · setup · org login  │
                    └──────────────────────┬───────────────────────┘
                                           │
               ┌───────────────────────────┼───────────────────────────┐
               ▼                           ▼                           ▼
   ┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
   │ Use case 1: Patient   │   │ Use case 2            │   │ Use case …            │
   │ vaccination XML       │   │ coming soon           │   │                       │
   │ own data, architecture│   │ own data, architecture│   │ own data, architecture│
   │ code and steps        │   │ code and steps        │   │ code and steps        │
   └───────────────────────┘   └───────────────────────┘   └───────────────────────┘
```

---

# Part 1: General introduction

This part applies to **every** use case. Read it first, and do the setup once.

## What is Code Extension?

Code Extension (also called *Bring Your Own Code*) lets you package a Python 3.11 script and run it in Data 360 as a **batch data transform**. You use it when the built-in transforms can't express your logic: parsing nested formats, custom cleansing, complex derivations and so on.

Every script follows the same pattern, whatever the use case:

```
                 ┌──────────────────────────────────────────┐
  Source DLO ───▶│  payload/entrypoint.py                   │───▶ Target DLO
  client.read_dlo│  Python 3.11 + PySpark + YOUR logic       │     client.write_to_dlo
                 └──────────────────────────────────────────┘
                     config.json declares the data space and
                     which DLOs the script may read and write
```

You work with the script in two modes:

| Mode | Command | Where it runs | What it does with the target DLO |
|---|---|---|---|
| **Develop locally** | `sf data-code-extension script run` | Spark on your laptop, reading **real data** from your org | Checks the columns exist, then **prints** the result. Nothing is written |
| **Run in Data 360** | `scan` → `zip` → `deploy`, then **Run Now** on the data transform | Inside Data 360, on the compute size you choose | **Writes** the target DLO. Logs go to `DataCustomCodeLogs__dll` |

## The general workflow

These steps are the same for every use case. Only the data, the objects and the logic change.

```
 Once:          1. Set up your laptop  ──▶  2. Authorize your org
                                                     │
 Per use case:  3. Prepare the data (source + target DLOs)
                4. Run the script locally
                5. Package, deploy, run the data transform and validate
```

| Step | Doc | What you do | Time |
|---|---|---|---|
| 1 | [docs/01-setup.md](docs/01-setup.md) | **Part A (once):** install the CLI, the plugin, uv, Python 3.11 and Java 17 without touching your system defaults. **Part B (every new terminal):** one command to re-enter the environment | 20–30 min |
| 2 | [docs/02-authorize-org.md](docs/02-authorize-org.md) | Connect your Data 360 org to the CLI as `byoc-org` | 5 min |
| – | [docs/troubleshooting.md](docs/troubleshooting.md) | Every error we hit while building this lab, with the fix | – |

**Opening a new terminal later?** Don't reinstall anything. From the repository root, run `source ./env.sh` (macOS) or `. .\env.ps1` (Windows). That's [Part B of the setup](docs/01-setup.md#part-b-every-new-terminal). Run `./verify.sh` (macOS) or `.\verify.ps1` (Windows) at any point to check your environment.

## Technical steps vs use-case steps

Inside the use-case docs, every section carries one of two labels:

- 🔧 **Technical:** how Code Extension works. It's identical in every use case: running locally, scan, zip, deploy, data transform, logs.
- 🩺 **Use case:** specific to that use case: its sample data, DLO names and fields, the logic in `entrypoint.py`, and the expected results.

When you move from one use case to the next, the 🔧 parts stay the same and the 🩺 parts change.

## Before you start

- A Data 360 org (Developer, Enterprise, Performance or Unlimited edition) where you're an admin, with **Code Extension** enabled in Feature Manager and the **Data Cloud Architect** permission set. Details are in [docs/01-setup.md](docs/01-setup.md#org-prerequisites).
- macOS or Windows, with permission to install tools.
- No prior Code Extension knowledge.

---

# Part 2: Use cases

Each use case has its own business problem, sample data, architecture, package folder and steps. Do [Part 1](#part-1-general-introduction) first, then pick a use case.

| # | Use case | What the script does | Package folder | Status |
|---|---|---|---|---|
| 1 | [Patient vaccination XML](#use-case-1-patient-vaccination-xml) | Parses nested XML clinic batches into one clean row per patient, with derived fields | [`patient-xml-transform/`](patient-xml-transform/) | Available |
| 2 | *To be announced* | | | Coming soon |

## Use case 1: Patient vaccination XML

> Based on an internal Salesforce demo kit. Its code and instructions have been corrected and expanded here into a lab that runs end to end on macOS and Windows.

### The business problem

A healthcare provider sends vaccination records as dense, nested XML. Each row in Data 360 is one **clinic batch** holding several patients, with names, dates of birth and vaccination histories buried in markup. In that shape you can't segment, filter or search the data. For example, you can't find "patients over 60 with no COVID vaccine", because age isn't a field and the vaccine list is inside a string.

### The solution

The script parses each XML blob, creates one row per `<Patient>` and derives clean fields: age, a standardized vaccine list, the most recent vaccination date and a COVID yes/no flag.

### Architecture of this use case

```
 Source DLO: Patients_Raw_XML__dll                Target DLO: Patients_Enriched__dll
 (4 rows: one XML clinic batch each)              (12 rows: one per patient)
 ┌──────────────────────────────────┐            ┌──────────────────────────────────────┐
 │ recordid__c  BATCH-NORTH-2024    │            │ patient_id__c  name__c  age__c        │
 │ rawxml__c    <ClinicBatch>       │            │ vaccines_received__c                  │
 │                <Patient>…        │            │ most_recent_vaccination_date__c       │
 │                <Patient>…        │            │ has_covid_vaccine__c                  │
 └────────────────┬─────────────────┘            └──────────────────▲───────────────────┘
                  │ client.read_dlo()                                │ client.write_to_dlo(OVERWRITE)
                  ▼                                                  │
        ┌────────────────────────────────────────────────────────────┴───┐
        │ patient-xml-transform/payload/entrypoint.py                     │
        │   parse XML → one dict per <Patient> → derive fields → Spark DF │
        └─────────────────────────────────────────────────────────────────┘
          Data in:   CSV file upload (data stream) → source DLO
          Runs as:   Code Extension "Patient_Data_Transformer" + batch data transform
```

Pattern: **one source DLO → one target DLO, one input row becomes many output rows** (flatten/explode).

### Steps

Do [Part 1](#part-1-general-introduction) first. This use case's docs live in its own folder, [`patient-xml-transform/docs/`](patient-xml-transform/docs/), and continue the numbering from step 3.

| Step | Doc | What you do | Type | Time |
|---|---|---|---|---|
| 3 | [03-prepare-data.md](patient-xml-transform/docs/03-prepare-data.md) | Upload the sample CSV (data stream and source DLO) and create the target DLO | 🩺 | 15 min |
| 4 | [04-run-locally.md](patient-xml-transform/docs/04-run-locally.md) | Run the script on your laptop against the real data | 🔧 | 10 min |
| 5 | [05-package-and-deploy.md](patient-xml-transform/docs/05-package-and-deploy.md) | Scan, zip, deploy, run the batch data transform, check results and logs | 🔧 (validation 🩺) | 20 min |

**Expected result:** 4 clinic batches in, 12 patient rows out, with the COVID flag at Yes = 5 and No = 7.

### Data and safety

The sample data in `patient-xml-transform/data/` is **fictional**: the names, dates of birth and vaccinations aren't real people. Even so, the lab follows the same rules you'd follow with real data. The script never prints record contents, and the validation queries return counts and IDs only. Code Extension logs land in the `DataCustomCodeLogs__dll` DLO, which **data governance policies don't cover**, so anything your code prints can be read by anyone with access to that DLO.

---

## Adding a new use case

Each new use case gets its own folder next to `patient-xml-transform/`, with the same structure: sample data, `payload/entrypoint.py` and `config.json`, and its own `docs/` folder. Its docs **start at `03`** (`03-prepare-data.md`, `04-run-locally.md`, `05-package-and-deploy.md`), because steps 1 and 2 are the shared Part 1. It also gets its own **architecture** section in this README. It reuses Part 1 as it is. In its docs, keep the 🔧 steps and write new 🩺 steps: the data and DLOs, the logic in `entrypoint.py` (the table in [step 4](patient-xml-transform/docs/04-run-locally.md#step-1-know-what-the-script-does) shows which parts of a script are reusable), the `--name` and `--description` you deploy with, and the expected results.

## Repository layout

```
.
├── README.md                       This page: general introduction + use case catalog
│
│   Part 1: general (every use case)
├── docs/
│   ├── 01-setup.md                 One-time install + per-terminal environment
│   ├── 02-authorize-org.md         Connect your org to the CLI
│   └── troubleshooting.md          All errors and fixes
├── env.sh / env.ps1                Enter the project environment in one command
├── verify.sh / verify.ps1          Preflight check (tools, versions, org connection)
│
│   Part 2, use case 1: patient vaccination XML (one folder per use case)
└── patient-xml-transform/          The Code Extension package; run all sf commands from here
    ├── docs/                       This use case's steps, numbered from 03
    │   ├── 03-prepare-data.md      Data stream, source and target DLOs
    │   ├── 04-run-locally.md       Local run
    │   ├── 05-package-and-deploy.md  Scan, zip, deploy, transform, validation, logs
    │   └── images/                 Screenshots
    ├── .datacustomcode_proj/       Package marker (type: script). Keep it
    ├── payload/
    │   ├── entrypoint.py           The transform
    │   └── config.json             Data space and read/write permissions (generated by scan)
    ├── requirements.txt            Python packages for the deployed code (none needed)
    ├── data/patients_raw_xml.csv   Sample data: 4 clinic batches, 12 patients
    └── queries/                    Validation and log queries
```

## Official references

- [Code Extension in Data 360](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/use-custom-code.html)
- [Set Up Salesforce CLI for Code Extension](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/set-up-sdk.html)
- [Quick Start](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/quickstart.html)
- [Code Extension CLI plugin (GitHub)](https://github.com/salesforcecli/plugin-data-code-extension)
- [Data Custom Code Python SDK (GitHub)](https://github.com/forcedotcom/datacloud-customcode-python-sdk) · [PyPI](https://pypi.org/project/salesforce-data-customcode/)
