# 1. Environment setup

[← README](../README.md) · Next: [2. Authorize your org →](02-authorize-org.md)

## Goal and guiding principle

Code Extension needs **exactly Python 3.11** and **Java 17**. You'll get both **without changing your laptop's defaults**:

- `uv` installs Python 3.11, and it lives **only** in the project's `.venv`.
- Java 17 is installed next to any JDK you already have and is selected **only** in the project terminal.
- The CLI plugin is added to `sf` without affecting your other plugins.

Official reference: [Set Up Salesforce CLI for Code Extension](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/set-up-sdk.html).

## What you'll install

| Component | Version | Why | Scope |
|---|---|---|---|
| Salesforce CLI (`sf`) | ≥ 2.130.9 | Runs every Code Extension command | Global |
| Node.js LTS + npm | LTS | Required **on Windows** by the official guide | Global |
| Code Extension plugin | ≥ 0.1.5 | Adds `sf data-code-extension …` | Added to `sf` |
| uv | Latest | Installs Python 3.11 and creates the isolated venv | User-level tool |
| Python | **Exactly 3.11** | Code Extension runtime. The plugin rejects every other version | Project `.venv` only |
| `salesforce-data-customcode` SDK | Latest | Python library and local Spark runner | Project `.venv` only |
| `pipreqs` | Latest | Used by `script scan` to detect your imports | Project `.venv` only |
| Azul Zulu OpenJDK | **17.x** | PySpark needs a JVM for local runs | Side by side, per terminal |

## Org prerequisites

- Edition: Developer, Enterprise, Performance or Unlimited ([availability](https://help.salesforce.com/s/articleView?id=sf.c360_a_dc_editions.htm&type=5)).
- **Code Extension** enabled in **Feature Manager** ([how to](https://help.salesforce.com/s/articleView?id=data.c360_a_feature_manager.htm&language=en_US&type=5)).
- Permission set **Data Cloud Architect** assigned to your user.
- The org must **not** have BYOK (Bring Your Own Key) enabled. Code Extension isn't supported there.

---

## Step 1: Salesforce CLI

```bash
sf version
```

If `sf` isn't found or the version is below 2.130.9, install it from [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm). Use the `.pkg` on macOS and the `.exe` on Windows. To update an existing install, run `sf update`.

> **You may face:** `@salesforce/cli update available from X to Y` on every command. This is informational only. Any version from 2.130.9 works, and the lab was built on 2.150.6.
>
> **You may face (Windows):** `sf` isn't recognized right after installing. The installer updated `PATH`, but only new terminals see it. Open a new terminal.

## Step 2: Node.js (Windows only)

Install [Node.js LTS](https://nodejs.org/en/download), then check it:

```powershell
node --version
npm --version
```

> **You may face (macOS):** `node` works but you get `npm: command not found`. This means a partial Node install. You can ignore it, because `sf` bundles its own Node and npm.

## Step 3: Code Extension plugin

```bash
sf plugins install @salesforce/plugin-data-code-extension
sf plugins
```

The output must list `data-code-extension` at version 0.1.5 or later.

> **You may face:** `data-code-extension script init is not a sf command`. Code Extension isn't part of the base CLI, so the plugin isn't installed yet. Run the install above.
>
> **You may face:** `npm error code ETARGET … No matching version found for …@X.Y.Z with a date before <date>`. Your npm setup only accepts packages older than a minimum age. This is often a corporate policy, and the newest plugin release is too recent. List the versions with their publish dates, then pin the newest one that's older than the date in the error.
>
> macOS:
> ```bash
> curl -s https://registry.npmjs.org/@salesforce/plugin-data-code-extension \
>   | python3 -c "import sys,json; t=json.load(sys.stdin)['time']; [print(k,v) for k,v in t.items() if k[0].isdigit()]" | tail -10
> ```
> Windows:
> ```powershell
> (Invoke-RestMethod https://registry.npmjs.org/@salesforce/plugin-data-code-extension).time
> ```
> Then install that version:
> ```bash
> sf plugins install @salesforce/plugin-data-code-extension@<version>
> ```

## Step 4: Install uv

macOS:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh      # or: brew install uv
```

Windows:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"   # or: winget install --id=astral-sh.uv -e
```

Open a new terminal and run `uv --version`.

> **Why uv?** To get Python 3.11, the official guide suggests pyenv on macOS, or python.org, the Microsoft Store or pyenv-win on Windows. uv does the same job with one tool on both platforms. It downloads the interpreter itself, keeps it out of your system Python and installs heavy dependencies (pyspark, pandas) much faster.

## Step 5: Clone the lab and create the Python 3.11 environment

The commands are the same on both platforms:

```bash
git clone https://github.com/adiazraya/byoc.git
cd byoc/patient-xml-transform
uv python install 3.11
uv venv --python 3.11 --seed .venv
```

Activate the venv and check the version:

macOS:

```bash
source .venv/bin/activate
python3 --version          # Python 3.11.x
```

Windows:

```powershell
.venv\Scripts\Activate.ps1
python --version           # Python 3.11.x
python3 --version          # must ALSO print 3.11.x
```

> **You may face:** `Error (PythonVersionMismatch): Python version 3.15.0 is installed, but exactly version 3.11 is required`. The plugin checks `python3` first, then `python`, on your `PATH`. It accepts **only** 3.11, so newer versions fail too, because Data 360 runs your code on 3.11. Don't downgrade your system Python. Activate the venv in every project terminal instead (Step 8 makes this one command).
>
> **You may face:** `Error (PackageNotInstalled): Required package 'salesforce-data-customcode' is not installed`, even though `uv pip show` finds it. By default, `uv venv` creates environments **without pip**, and the plugin checks the SDK with `pip`/`python3 -m pip show`. The `--seed` flag above adds pip. If you already created the venv without it, run `uv pip install pip`.
>
> **You may face (Windows):** `Activate.ps1 cannot be loaded because running scripts is disabled on this system`. PowerShell's execution policy blocks scripts. Allow them **for this session only**: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.
>
> **You may face (Windows):** `python3` opens the Microsoft Store, or `python3 --version` prints nothing. Windows ships "App execution aliases" that shadow the venv's `python3`. Turn off the `python.exe` and `python3.exe` entries in **Settings → Apps → Advanced app settings → App execution aliases**, then open a new terminal.

## Step 6: Install the SDK inside the venv

With the venv active, inside `patient-xml-transform`:

```bash
uv pip install salesforce-data-customcode pipreqs
python -m pip show salesforce-data-customcode
```

The official guide uses `python3.11 -m pip install …` on macOS or `py -3.11 -m pip install …` on Windows. Inside the active venv, `uv pip install` does the same and keeps the SDK out of your global Python. The first install pulls in pyspark, pandas and numpy, so it can take a few minutes.

`pipreqs` isn't in the official list. `script scan` calls it to work out which packages your script imports, and without it scan fails (see [Step 1 of the deploy doc](04-package-and-deploy.md#step-1-scan)).

## Step 7: Java 17 (Azul Zulu)

macOS:

```bash
brew install --cask zulu@17
/usr/libexec/java_home -V          # lists every installed JDK; 17.x must be there
```

Windows:

```powershell
winget install -e --id Azul.Zulu.17.JDK
dir "C:\Program Files\Zulu"        # a zulu-17… folder must be there
```

Installers are also available at [azul.com/downloads](https://www.azul.com/downloads/?version=java-17-lts&package=jdk). See also [Installing Azul Zulu on Windows](https://docs.azul.com/core/install/windows).

> **You may face:** `spark-class: line 97: CMD: bad array subscript`, `head: illegal line count -- -1` and `[JAVA_GATEWAY_EXITED] Java gateway process exited before sending its port number` on the first local run. PySpark can't find a usable JDK. Install Zulu 17 and set `JAVA_HOME` in the same terminal, which Step 8 does for you.
>
> **You may face (Windows):** `WARN Shell: Did not find winutils.exe` / `HADOOP_HOME and hadoop.home.dir are unset`. Local Spark looks for Hadoop helpers. This is usually harmless, because the lab reads and writes Data 360, not your local disk. Only if a local file write fails, put `winutils.exe` in `C:\hadoop\bin` and set `$env:HADOOP_HOME="C:\hadoop"`.
>
> **You may face (Windows):** `Python worker failed to connect back`. Spark started the wrong Python for its workers. Set `PYSPARK_PYTHON` to the venv's Python, which Step 8 also does.

## Step 8: Enter the project environment with one command

Do this **in every new terminal**, from the repository root (`byoc/`). The scripts change nothing globally.

macOS: [`env.sh`](../env.sh)

```bash
cd byoc
source ./env.sh
```

Windows: [`env.ps1`](../env.ps1)

```powershell
cd byoc
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. .\env.ps1
```

Each script:

1. Activates `patient-xml-transform/.venv`.
2. Sets `JAVA_HOME` to Java 17 and puts it first on `PATH`.
3. Sets `PYSPARK_PYTHON` to the venv's Python.
4. Prints the Python and Java versions.

> **You may face:** `Run this with 'source ./env.sh'` or `Dot-source this script`. You ran the script as a program, so its settings died with it. Use `source ./env.sh` on macOS, or `. .\env.ps1` on Windows (dot, space, path).
>
> **Note:** `uv run sf data-code-extension …` also runs inside the venv without activating it, but you still need Java 17 on `JAVA_HOME`. The env scripts handle both, so the rest of the lab assumes you used them.

## Step 9: Run the preflight check

From the repository root:

macOS:

```bash
./verify.sh byoc-org
```

Windows:

```powershell
.\verify.ps1 -OrgAlias byoc-org
```

The check is read-only. It covers the CLI and plugin versions, Python 3.11 on the `PATH`, pip and the SDK inside the venv, `pipreqs`, Java 17 on `JAVA_HOME` and the org connection. Every failed check prints the command that fixes it.

The **org** check fails until you finish [2. Authorize your org](02-authorize-org.md). That's expected at this point.

---

[← README](../README.md) · Next: [2. Authorize your org →](02-authorize-org.md)
