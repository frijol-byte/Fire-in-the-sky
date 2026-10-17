# Live Blender with Claude on Windows (optional)

This is **optional**. The normal workflow needs none of it: cloud sessions write Blender
scripts, build the models and show you preview pictures in the PR (see
[`owner-quickstart.md`](owner-quickstart.md)). Use this guide only if you want to *watch* a
model being built in Blender on your own PC and steer it live ("make the wings longer",
"more menacing").

You don't need to know Blender. You will need about 30 minutes the first time.

> **Terms:** *MCP* is the standard way Claude plugs into other programs. A *Blender MCP* has
> two halves: an **add-on** inside Blender (it listens for commands on your own PC) and a
> small **server** that Claude launches to talk to that add-on.

---

## The one rule: write back to the recipe

**A model that only exists in the Blender window does not exist for the game.**

The game's ships are built by Python scripts ("recipes") in `tools/blender/recipes/`, and the
`.glb` files are generated from them. So at the end of every live session you must make Claude:

1. Copy every change you liked **into the recipe script** (for example
   `tools/blender/recipes/ships/<ship>.py`), not just into the open Blender scene.
2. Save that script change to the repo (commit and push to a branch).

Say this at the end of every live session, word for word:

```
Write everything we changed into the recipe script in tools/blender/recipes/, so the
recipe rebuilds exactly what I see. Do not leave any change that only exists in the open
Blender scene. Then commit it to a new branch and tell me the branch name.
```

Then hand the branch to a normal cloud session, which rebuilds the model with the real
build script, checks it, and opens the PR (section 7). Don't save the `.blend` file into
the repo and don't export `.glb` files by hand; those are never the source of truth.

---

## 1. Install Blender 5.2 LTS

The project's build tools use Blender 5.2 LTS, so install the same version to see the same results.

1. In your browser go to `https://www.blender.org/download/`.
2. Under **Blender 5.2 LTS** (the "LTS" release; not a newer non-LTS one), click
   **Download Blender 5.2 LTS** for Windows. Choose the **Windows Installer (.msi)** if
   offered.
3. Open the downloaded `.msi`. Click **Next** → tick the license box → **Next** → **Next** →
   **Install**. If Windows asks "Do you want to allow this app to make changes", click **Yes**.
4. Click **Finish**. Open the Start menu, type **Blender**, and press Enter.
5. A splash screen appears. Click anywhere outside it. You should see a grey grid with a
   cube. The version number is bottom-right of the window.

## 2. Install the helper tool `uv`

The Blender MCP server is a Python program that `uv` downloads and runs for you.

1. Press the Windows key, type **PowerShell**, click **Windows PowerShell** (no need for
   "Run as administrator").
2. Paste this line and press Enter:

   ```
   powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

3. When it finishes, **close PowerShell and open a new one**, then type:

   ```
   uvx --version
   ```

   You should see a version number. If you see "not recognized", sign out of Windows and
   back in (this refreshes your PATH), then try again.
4. Type `where uvx` and press Enter. **Write down the path it prints**
   (like `C:\Users\you\.local\bin\uvx.exe`); you may need it in section 4.

## 3. Choose and install the Blender add-on

**Which Blender MCP, and why**

| Option | Verdict |
|---|---|
| **`mcp-for-blender`** (GitHub: `ahujasid/blender-mcp`; the PyPI package was renamed from `blender-mcp`, existing setups keep working) | **Use this one.** The most widely used and documented, with a one-command add-on install, and works with Blender 3.0 and newer, so also 5.2. It supports Claude Desktop and Claude Code, and its steps below were taken from its own README. |
| Blender Lab's official MCP server (from the Blender project itself) | Worth watching. At the time of writing, third-party write-ups described it as an official but **experimental** Blender Lab project needing Blender 5.1+. We could not open Blender's own pages from the research session to confirm its install steps, so this guide does not depend on it. If you later switch, the write-back rule is unchanged. |
| Other community servers | Smaller and less documented. Skip. |

> **Safety:** this add-on lets Claude run Python code inside Blender, and its local connection
> has no password. It only listens on your own PC (`localhost`), and Blender can read and
> write your files like any program you run. So: **save your work first**, keep Blender
> closed when you're not using it, and only connect Claude you trust. Optional extra guard: set the environment variable
> `BLENDER_MCP_SAFE_MODE=1` (Windows search → "Edit the system environment variables" →
> **Environment Variables…** → under *User variables* click **New…** → name
> `BLENDER_MCP_SAFE_MODE`, value `1` → **OK**), which makes the server refuse scripts
> that touch files, other programs or the network.

**Install the add-on (easy way)**

1. Close Blender.
2. In PowerShell run:

   ```
   uvx mcp-for-blender install-addon
   ```

   It copies the add-on into Blender's add-on folder. (The first run downloads some files and
   can take a minute.)
3. Open Blender. Go to **Edit** (top-left menu) → **Preferences…** → **Add-ons** (left side).
4. In the search box type `MCP`. Tick the box next to **Interface: MCP for Blender**.

**If the add-on doesn't show up (manual way)**

1. Download `addon.py` from `https://github.com/ahujasid/blender-mcp`: open the file in
   GitHub, click the download icon (**Download raw file**, top-right of the file view).
2. In Blender: **Edit** → **Preferences…** → **Add-ons** → click the small **drop-down arrow**
   at the top right of the Add-ons panel → **Install from Disk…** → pick `addon.py` →
   **Install from Disk**.
3. Search `MCP` and tick **Interface: MCP for Blender**.

**Start the Blender side**

1. Click on the 3D viewport (the big grid area), then press **N** to open the side panel.
2. Click the **MCP for Blender** tab (vertical tabs along the panel's right edge).
3. Click **Start MCP Server** (it may already be running). The default port is `9876`; leave
   it as is.

## 4. Connect Claude

Pick **one** of the two. Don't run both at the same time.

### Option A: Claude Desktop (easiest for watching and chatting)

1. Install Claude Desktop from `https://claude.ai/download` and sign in.
2. Open Claude Desktop → click your name/the menu at the bottom-left → **Settings** →
   **Developer** → **Edit Config**. A folder opens showing `claude_desktop_config.json`.
3. Open that file with Notepad (right-click → **Open with** → **Notepad**). Replace its
   contents with the following (if the file already has other servers, add only the
   `"blender"` block inside the existing `"mcpServers"`, keeping the commas right):

   ```json
   {
     "mcpServers": {
       "blender": {
         "command": "uvx",
         "args": ["mcp-for-blender"]
       }
     }
   }
   ```

   If Claude later reports `spawn uvx ENOENT`, replace `"uvx"` with the full path from
   section 2 step 4, using double backslashes: `"C:\\Users\\you\\.local\\bin\\uvx.exe"`.
4. Save, then **fully quit Claude Desktop** (right-click its icon in the system tray near the
   clock → **Quit**; closing the window is not enough) and open it again.
5. In a new chat, click the **+** (or the tools/connector icon) at the left of the message
   box and check that **blender** appears with tools listed.

### Option B: Claude Code on Windows

1. Install Claude Code by following `https://code.claude.com/docs/en/quickstart` (it has a
   Windows tab). Open PowerShell inside the project folder (clone the repo first with
   GitHub Desktop, or `git clone https://github.com/frijol-byte/Fire-in-the-sky`).
2. Register the server once:

   ```
   claude mcp add blender uvx mcp-for-blender
   ```

3. Start Claude Code with `claude`, then type `/mcp` and press Enter. **blender** should be
   listed as connected. If not, quit and start `claude` again.

### Both options: connect the two halves

Back in Blender, in the **MCP for Blender** panel (N → tab), turn on the features you want
and click **Connect to Claude**. Leave Blender open. Keep the Blender window visible while
Claude works; you'll see the objects appear.

## 5. First test prompt

Start with an empty scene (**File** → **New** → **General**), then paste to Claude:

```
Look at my Blender scene first and tell me what's in it. Then delete the default cube and
make a simple spaceship: a long body, two swept-back wings and two round engines at the
back. Use flat grey for the hull. Take a screenshot of the viewport and show me.
```

**Success looks like:** a small ship appears in Blender and Claude shows you a screenshot.

Then try steering it, one change at a time:

```
Make the wings 30% longer and tilt them back more. Show me a screenshot.
```

```
Make the nose sharper and add a red stripe on top of the body.
```

Good habits: ask for **one change at a time**, ask for a screenshot after each, and say
"undo that" if you don't like it.

## 6. Use it on a real ship

To iterate on an actual game ship instead of a test, ask Claude (in Claude Code, inside the
project folder) to run the recipe in your open Blender window so you can see and tweak
it:

```
Open the ship recipe tools/blender/recipes/ships/<ship>.py, run its build in my open
Blender scene so I can see it, then change it as I describe. Read tools/blender/ and
docs/04-art-audio-bible.md section 3 first. Keep the naming rules (SOCKET_*, T1_*, T0ONLY_*).
```

Claude can read the art rules from the repo, which keeps the model game-ready. Finish with the
write-back message from the top of this guide.

## 7. After the live session: turn it into a PR

1. Make sure the branch you were told about is pushed to GitHub.
2. Start a cloud session (see `owner-quickstart.md` §2) with:

   ```
   Do an art-iteration task on branch <the branch name>: rebuild the model from the recipe
   with tools/blender/build.py, look at the preview PNGs, make sure tools/check.sh passes,
   and open a PR. Follow CLAUDE.md.
   ```

3. Review the previews in the PR like any other PR. Say what's wrong in plain words and
   the session adjusts the recipe.

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| Claude says it can't find / connect to Blender | In Blender: N panel → **MCP for Blender** tab → is the server running? Click **Start MCP Server**, then **Connect to Claude**. Make sure Blender is open. Then quit and reopen Claude (Desktop: quit from the system tray). |
| `uvx` "is not recognized" | The PATH wasn't refreshed. Close all PowerShell windows and Claude, sign out of Windows and back in, retry `uvx --version`. If still failing, re-run the install line in section 2. |
| `spawn uvx ENOENT` in Claude Desktop | Use the full path to `uvx.exe` (section 4A step 3). |
| Add-on "MCP for Blender" isn't in the list | Use the manual way in section 3. Then restart Blender. |
| "Connection refused" or timeouts | Another program may be using port `9876`. In PowerShell: `netstat -ano | findstr 9876`. Close the other program (or an old Blender/Claude window) and retry. Also run only **one** MCP client (Desktop *or* Code) at a time. |
| Windows Firewall pop-up | Choose **Private networks** and **Allow access**. The connection is local to your PC. |
| A request takes forever / Blender freezes | Big requests (e.g. downloading textures) run inside Blender's main thread. Wait, or ask for smaller steps. If it's stuck for minutes, close Blender (you lose unsaved work; save often) and start again. |
| Claude's changes don't show up in the game | Expected! Only recipes in `tools/blender/recipes/` count. Redo the write-back (top of this guide). |
| You want to update the tool | In PowerShell: `uvx mcp-for-blender@latest update`. Re-do the "Connect to Claude" step in Blender. |
| Nothing works | Skip it. The normal workflow doesn't need this guide: describe the look you want in a PR comment and a cloud session adjusts the recipe. |

*Sources used for this guide: the project README of `mcp-for-blender` /
[`ahujasid/blender-mcp`](https://github.com/ahujasid/blender-mcp), cross-checked with
third-party setup guides
([Vagon](https://vagon.io/blog/how-to-use-blender-mcp-with-anthropic-claude-ai),
[CloudThat](https://www.cloudthat.com/resources/blog/integrating-claude-desktop-app-with-blender-using-mcp-server)).
The note on Blender Lab's official server comes from third-party write-ups
([example](https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026)),
not from Blender's own pages. Check the current README before installing, because MCP
tools change quickly.*
