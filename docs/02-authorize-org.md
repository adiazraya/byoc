# 2. Authorize your Data 360 org

[← 1. Setup](01-setup.md) · Next: [Pick a use case →](../README.md#part-2-use-cases)

The Code Extension plugin uses the org session that Salesforce CLI has saved. You authorize once, and every `run` and `deploy` reuses that session through `--target-org`. You don't need a connected app or an External Client App for this path.

> The SDK's standalone CLI (`datacustomcode configure`) uses a different authentication method, based on an External Client App. This lab doesn't use it. If you need that path, see [Set Up an External Client App for Data Custom Code SDK](https://developer.salesforce.com/docs/data/data-cloud-code-ext/guide/configure-data-cloud.html).

## Step 1: Find your login URL

| Your org | Login URL |
|---|---|
| Production, Developer Edition or trial | `https://login.salesforce.com` (default) |
| Sandbox | `https://test.salesforce.com` |
| Org that enforces My Domain login | `https://<yourdomain>.my.salesforce.com` |

To find your My Domain, open **Setup → My Domain** in the org.

## Step 2: Log in from the CLI

The commands are the same on macOS and Windows:

```bash
# Production / Developer Edition / trial
sf org login web --alias byoc-org

# Sandbox
sf org login web --alias byoc-org --instance-url https://test.salesforce.com

# My Domain
sf org login web --alias byoc-org --instance-url https://<yourdomain>.my.salesforce.com
```

Your browser opens the Salesforce login page. Log in, click **Allow** on the access screen and go back to the terminal. You should see `Successfully authorized <username> with org ID …`.

> **You may face:** the browser logs you straight into a **different** org that you're already signed in to, and the CLI authorizes the wrong one. Log out of Salesforce in the browser first. Or force a specific browser with `--browser chrome` (or `firefox`, `edge`) and use a private window, then run the command again. Always confirm the result with Step 3.
>
> **You may face:** the login page loops, or says your domain is invalid. The org enforces My Domain login. Use the `--instance-url https://<yourdomain>.my.salesforce.com` variant.
>
> **You may face:** the browser shows `localhost refused to connect`, or the CLI hangs after you click **Allow**. The CLI receives the login callback on `http://localhost:1717`, and a VPN, a firewall or another process using port 1717 can block it. Disconnect the VPN or close the other process, then try again.
>
> **You may face:** you're on a machine with no usable browser (a remote VM, a locked-down laptop). The web flow needs a local browser. Log in on a machine that has one, run `sf org display --target-org byoc-org --verbose --json` there, and copy the `sfdxAuthUrl` value into a file. Then, on the other machine, run `sf org login sfdx-url --sfdx-url-file <file> --alias byoc-org`. Treat that file like a password and delete it afterwards.
>
> **You may face (Windows):** the browser doesn't open at all. Copy the URL printed in the terminal into a browser yourself.

## Step 3: Verify the connection

```bash
sf org list
sf org display --target-org byoc-org
```

Check that **Connected Status** is `Connected`, and that **Username** and **Instance Url** are the ones you expect. To open the org from the CLI:

```bash
sf org open --target-org byoc-org
```

You can also rerun the preflight. Its last check should now pass:

```bash
./verify.sh byoc-org                 # macOS
.\verify.ps1 -OrgAlias byoc-org      # Windows
```

## Step 4: Always pass `--target-org byoc-org`

Every command in this lab passes `-o byoc-org` (short for `--target-org`) explicitly. Keep doing so. If you have several orgs, your CLI's **default** org may be a different one. When a command reads one org and you inspect another, you get confusing results, such as "table does not exist" for a DLO you can see in the UI.

> `sf config set target-org byoc-org` only works inside a Salesforce DX project (a folder with `sfdx-project.json`). This lab's folder isn't one, so the command fails with `InvalidProjectWorkspaceError`. Don't fix that with `--global`, because it changes the default for every project on your laptop. Just keep passing `-o byoc-org`.

## Step 5: Confirm Data 360 access

The CLI login only proves that your user can log in. The local run also calls Data 360 APIs, so check these in the org:

- **Data Cloud Architect** is assigned: Setup → Users → your user → Permission Set Assignments.
- **Code Extension** is enabled in Feature Manager.
- Data 360 is provisioned: you can open **Data Cloud Setup** and the **Data Lake Objects** tab.

> **You may face:** a local run that authenticates (`Successfully authenticated with org …`) but then fails with `401`, `403` or `INSUFFICIENT_ACCESS`. Your user is missing the permission set, or Data 360 isn't available to it. Fix it in the org. You don't need to log in again.
>
> **You may face:** `This feature is not currently enabled for this user type or org: [CdpCustomCodeDeployment]` on `script deploy`. **Code Extension** isn't enabled in Feature Manager. Enable it and run the deploy again. Nothing was created by the failed attempt.
>
> **You may face:** `No authorization information found for byoc-org`, or an expired session after a few days. The alias was never created, or its session expired. Run `sf org login web --alias byoc-org` again. To remove an org from the CLI, run `sf org logout --target-org byoc-org`.

---

[← 1. Setup](01-setup.md) · Next: [Pick a use case →](../README.md#part-2-use-cases)
