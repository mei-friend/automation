# mei-friend automation — Central Repository

This is the **default central repository** for the [mei-friend](https://mei-friend.github.io) GitHub Actions automation setup.
It contains the reusable workflow and processing scripts that operate on MEI files stored in caller repositories created from the [caller template](https://github.com/mei-friend/caller-template).

For an end-to-end description of the automation mechanism, see the [mei-friend automation documentation](https://mei-friend.github.io/docs/advanced/automation/).

---

## Role in the automation architecture

mei-friend's automation has three components:

```
mei-friend (browser)
      │
      │  triggers via GitHub API (workflow_dispatch)
      ▼
Caller repository           ← user's own repo, contains MEI files
  .github/workflows/
    caller.yml              ← thin relay, points to a central repo via `uses:`
      │
      │  workflow_call
      ▼
This repository  (mei-friend/automation)   ← you are here
  .github/workflows/        ← reusable workflow definitions
  scripts/                  ← Python processing scripts
      │
      │  checks out both repos, runs scripts, commits results back
      ▼
Caller repository           ← results committed back here
```

Caller repositories created from the [caller template](https://github.com/mei-friend/caller-template) point at this repository by default. Project-specific central repositories (e.g. [E-LAUTE](https://github.com/e-laute/E-LAUTE_GH_Actions)) follow the same pattern but expose their own scripts and work packages.

---

## Repository structure

```
automation/
│
├── .github/workflows/
│   └── central.yml                # Reusable workflow invoked by caller repos
│                                  # (central_v2.yml is an in-progress successor;
│                                  #  see "Workflow versions" below)
│
├── scripts/
│   ├── coordinator.py             # Parses the MEI file, runs the scripts in order, writes back
│   ├── script_collection.py       # Library of reusable MEI transformation functions
│   ├── template_script.py         # Starting point for new scripts
│   ├── utils.py                   # Shared helpers (XML utilities, GitHub summary output)
│   ├── testing_scripts.py         # Local test harness
│   └── requirements.txt           # Python dependencies installed in the runner
│
├── work_packages.json             # Example/default work package definitions
├── work_package_template.json     # Annotated template for writing your own
└── update_secrets.sh              # Helper for managing repository secrets
```

### Workflow versions

`central.yml` is the workflow currently invoked by the caller template. `central_v2.yml` is an in-progress revision with a cleaner input schema (`work_package`, `parameters`) and is not yet wired up; once mei-friend's dispatch payload is updated to match, the caller template will be switched over.

---

## How the coordinator works

`scripts/coordinator.py` is the engine behind every work-package run. When invoked it:

1. **Parses the target file** at the given path with `lxml`, wrapping the resulting tree in a metadata dictionary (`filename`, `dom`, plus any project-specific fields). This is the **active DOM**.
2. **Collects context DOMs** — sibling files in the same directory that the scripts may want to read from (returns an empty list in the generic setup; project-specific central repos may populate this).
3. **Imports and runs the scripts** listed in the work package definition. Each script receives the active DOM, the context DOMs, and the user-supplied parameters; its return value is passed to the next script in the chain.
4. **Writes the result back** to the original file if `commitResult` is `true`, and appends a provenance entry to the MEI `<appInfo>` block. The surrounding workflow then commits the change to the caller repository.

If any script raises a `RuntimeError`, execution stops immediately and no file is written.

---

## Work packages

Work packages are JSON entries that describe a single named operation selectable in mei-friend. The shape is:

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

| Field | Purpose |
|---|---|
| `id` | Internal identifier, used as `workpackage_id` when triggering the workflow |
| `label` | Display name shown in mei-friend |
| `description` | Tooltip shown in mei-friend |
| `userFacing` | Whether to show this work package in the mei-friend dropdown |
| `params` | Parameters the user can fill in; each may have a `default` and a `type` (`"String"` or `"Number"`) |
| `scripts` | Ordered list of `module.function` paths, executed in sequence |
| `commitResult` | Whether to write the result back and commit it |

The bundled [`work_packages.json`](work_packages.json) lists the default work packages provided by this repository.
[`work_package_template.json`](work_package_template.json) is an annotated template for creating your own.

To use a custom work package definition, host the JSON at a publicly accessible, CORS-enabled URL and paste that URL into mei-friend's **"Custom configuration"** field.

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

Caller repositories created from the [caller template](https://github.com/mei-friend/caller-template) already point here. The relevant line in their `.github/workflows/caller.yml` is:

```yaml
jobs:
  call-shared:
    uses: mei-friend/automation/.github/workflows/central.yml@main
```

To use a different central repository, change that `uses:` line. See [Setting up your own central repository](https://mei-friend.github.io/docs/advanced/automation/#setting-up-your-own-central-repository) in the docs.
