# mei-friend automation — Central Repository

This is the **default central repository** for the [mei-friend](https://mei-friend.github.io) GitHub Actions automation setup.
It contains the runner shell script that gets invoked by the caller workflowand the processing scripts that operate on MEI files stored in caller repositories created from the [caller template](https://github.com/mei-friend/caller-template).
Also provided are an example work package definition as well as a template and a helper script for managing repository secrets.

For an end-to-end description of the automation mechanism, see the [mei-friend automation documentation](https://mei-friend.github.io/docs/advanced/automation/).

---

## Role in the automation architecture

mei-friend's automation has three components:

```
mei-friend (browser)
      │
      │  triggers via GitHub API (workflow_dispatch)
      ▼
Caller repository               ← user's own repo, contains MEI files
  .github/workflows/caller.yml  ← checks out both repos, runs the central shell script
      │
      │  bash central-repo/scripts/run_automation.sh
      ▼
This repository  (mei-friend/automation)   ← you are here
  automation/run_automation.sh          ← entry point: sets up Python environment and runs coordinator.py
  scripts/                      ← Python processing scripts
      │
      ▼
Caller repository               ← results committed back here
```

Caller repositories created from the [caller template](https://github.com/mei-friend/caller-template) point at this repository by default. Project-specific central repositories (e.g. [E-LAUTE](https://github.com/e-laute/automation)) follow the same pattern but expose their own scripts and work packages.

---

## Repository structure

```
automation/
│
├── automation/
│   └── run_automation.sh          # Entry point: installs deps and runs coordinator.py
|
├── scripts/
│   ├── coordinator.py             # Parses the MEI file, runs the scripts in order, writes back
│   ├── script_collection.py       # Library of reusable MEI transformation functions
│   ├── utils.py                   # Shared helpers (XML utilities, GitHub summary output)
│   └── requirements.txt           # Python dependencies installed in the runner
│
├── work_packages.json             # Example/default work package definitions
├── work_package_template.json     # Annotated template for writing your own
└── update_secrets.sh              # Helper for managing repository secrets
```

## How the coordinator works

`scripts/coordinator.py` is the engine behind every work-package run. When invoked it:

1. **Parses the target file** at the given path with `lxml`, wrapping the resulting tree in a metadata dictionary (`filename`, `dom`, plus any project-specific fields). This is the **active DOM**.
2. **Collects context DOMs** — sibling files in the same directory that the scripts may want to read from (returns an empty list in the generic setup; project-specific central repos may populate this).
3. **Imports and runs the scripts** listed in the work package definition. Each script receives the active DOM, the context DOMs, and the user-supplied parameters; its return value is passed to the next script in the chain.
4. **Writes the result back** to the original file if `commitResult` is `true`, and appends a provenance entry to the MEI `<appInfo>` block. The surrounding workflow then commits the change to the caller repository.

If any script raises a `RuntimeError`, execution stops immediately and no file is written.

This setup allows scripts to build on each other and share a common parsing and writing mechanism, while keeping the individual transformation functions modular and reusable.
It is not necessary to use a setup like this, any other structure is possible as long as the entry point script specified in the work package JSON can be invoked from the central repository.

---

## Work packages

Work packages are JSON entries that describe a single named operation ("work package") selectable in mei-friend. The shape is:

```json
{
  "id": "add_sbs",
  "label": "Add system beginnings",
  "description": "Adds <sb/> every n measures.",
  "userFacing": true,
  "params": {
    "sbInterval": {
      "type": "Number",
      "default": 5,
      "description": "Places an <sb/> element every n measures."
    }
  },
  "scripts": [
    "script_collection.remove_all_sbs",
    "script_collection.add_sbs_every_n"
  ],
  "commitResult": true
}
```

| Field          | Purpose                                                                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`           | Internal identifier, used as `workpackage_id` when triggering the workflow                                                                             |
| `label`        | Display name shown in mei-friend                                                                                                                       |
| `description`  | Description shown in mei-friend                                                                                                                        |
| `userFacing`   | Whether to show this work package in the mei-friend dropdown                                                                                           |
| `params`       | Parameters the user can fill in; each may have a `default`, a `type` (`"String"` or `"Number"`) and a `description`m shown as a tooltip in mei-friend. |
| `scripts`      | Ordered list of `module.function` paths, executed in sequence                                                                                          |
| `commitResult` | Whether to write the result back and commit it                                                                                                         |

The bundled [`work_packages.json`](work_packages.json) lists the default work packages provided by this repository.
[`work_package_template.json`](work_package_template.json) is an annotated template for creating your own.

To use a custom work package definition, host the JSON at a publicly accessible, CORS-enabled URL and paste that URL into mei-friend's **"Custom configuration"** field. For example your JSON could live in your caller repository itself (provided it's publicly accessible), or in a separate public repository for your project.

---

## Writing new scripts

Scripts live in [`scripts/script_collection.py`](scripts/script_collection.py) (or a new module in the same directory). Every script function must follow this signature:

```python
def my_script(active_dom: dict, context_doms: list, **params):
    """
    active_dom:   {"filename": str, "dom": lxml.etree.Element, ...}
    context_doms: list of the same structure, one per sibling file
    params:       keyword arguments declared in the work package JSON
    """
    root = active_dom["dom"]

    # ... modify root ...

    active_dom["dom"] = root
    output_message = "Human-readable result shown in the Actions log"
    summary_message = "| table row | for | GitHub summary |"
    return active_dom, output_message, summary_message
```

Rules:

- Raise `RuntimeError` to abort the work package and leave the file unchanged.
- Do not write to disk — the coordinator handles that.
- Use `**params` to absorb any parameters from the JSON the function does not use.

[`scripts/template_script.py`](scripts/template_script.py) provides a minimal starting point.

Once a function exists, register it as a work package entry in your JSON file and it becomes available in mei-friend.

---

## Connecting a caller repository to this central repository

Each work package configuration JSON specifies which central repository to use via three top-level fields:

```json
{
  "central_repository": "mei-friend/automation",
  "branch": "main",
  "automation": "automation/run_automation.sh",
  "work_packages": [...]
}
```

| Field                | Purpose                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `central_repository` | The `owner/repo` of the repository containing the automation logic |
| `branch`             | The branch of that repository to check out                         |
| `automation`         | Path to the entry-point shell script within that repository        |

mei-friend reads these fields from the work package JSON and passes them as inputs when dispatching `caller.yml`. The caller workflow checks out the specified central repository and runs the script at the given path — no changes to `caller.yml` are needed to switch central repositories.

To point to a different central repository (e.g. a project-specific one), update these three fields in the work package JSON. See [Setting up your own central repository](https://mei-friend.github.io/docs/advanced/automation/#setting-up-your-own-central-repository) in the docs.
