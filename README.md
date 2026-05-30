# Vivado XSIM Runner

A small PowerShell wrapper for running a single Verilog/SystemVerilog file with Xilinx Vivado XSIM from VS Code or a terminal.

The script compiles with `xvlog`, elaborates with `xelab`, and runs with `xsim`. Vivado is not included and must be installed separately.

## Requirements

- Windows PowerShell or PowerShell
- Xilinx Vivado with `xvlog`, `xelab`, and `xsim` available on `PATH`
- VS Code and the Code Runner extension, if you want the editor run button workflow

If the tools are not found, start VS Code from a Vivado-enabled shell or add Vivado's `bin` directory to `PATH`.

## Where To Put It

There are two supported layouts.

### Global Install

Use this if you want to install the runner once and use it from any HDL workspace.

```powershell
git clone <repo-url>
cd vivado-xsim-runner
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

This installs the runner here:

```text
%USERPROFILE%\.xsim-runner\run_xsim.ps1
```

For VS Code tasks, copy `examples/global-tasks.json` to your VS Code User Tasks file.

For Code Runner's run button, add this to your VS Code user `settings.json`:

```json
{
  "code-runner.runInTerminal": true,
  "code-runner.executorMapByFileExtension": {
    ".sv": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.xsim-runner\\run_xsim.ps1\" -FilePath \"$fullFileName\" -WorkspaceRoot \"$workspaceRoot\"",
    ".v": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.xsim-runner\\run_xsim.ps1\" -FilePath \"$fullFileName\" -WorkspaceRoot \"$workspaceRoot\""
  }
}
```

After that, open any Verilog/SystemVerilog workspace and use the same VS Code run button.

### Workspace Install

Use this if you want the runner checked into a specific HDL project.

For an existing HDL project, copy this repository's `scripts` folder into the root of that project:

```text
your-hdl-project/
  scripts/
    run_xsim.ps1
  design_or_testbench.sv
```

The VS Code examples expect the script at:

```text
${workspaceFolder}\scripts\run_xsim.ps1
```

That means if your workspace is `D:\verilog\my_project`, the script should be here:

```text
D:\verilog\my_project\scripts\run_xsim.ps1
```

## Terminal Usage

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_xsim.ps1 -FilePath .\examples\simple_tb.sv -WorkspaceRoot .
```

Open the simulation GUI:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_xsim.ps1 -FilePath .\examples\simple_tb.sv -WorkspaceRoot . -Gui
```

## VS Code Code Runner Button

Add this to your VS Code `settings.json` or workspace `.vscode/settings.json` after copying the `scripts` folder into your HDL workspace:

```json
{
  "code-runner.runInTerminal": true,
  "code-runner.executorMapByFileExtension": {
    ".sv": "powershell -ExecutionPolicy Bypass -File \"$workspaceRoot\\scripts\\run_xsim.ps1\" -FilePath \"$fullFileName\" -WorkspaceRoot \"$workspaceRoot\"",
    ".v": "powershell -ExecutionPolicy Bypass -File \"$workspaceRoot\\scripts\\run_xsim.ps1\" -FilePath \"$fullFileName\" -WorkspaceRoot \"$workspaceRoot\""
  }
}
```

Then open a `.sv` or `.v` file and click Code Runner's run button.

## VS Code Tasks

If you prefer VS Code tasks, copy `examples/tasks.json` to `.vscode/tasks.json` in your HDL workspace.

Run the current file from Command Palette:

```text
Tasks: Run Test Task
```

## File Conventions

The runner supports a few lightweight conventions:

- Top module: autodetects the last `module` in the current file, otherwise defaults to `tb`.
- Explicit top module: add `// xsim-top: my_tb` in the source file, or pass `-Top my_tb`.
- File list: if `xsim.f` exists beside the current source file, the runner compiles that file list instead of only the current file.
- Batch commands: if `xsim.tcl` exists beside the current source file, the runner uses it with `xsim -tclbatch`.
- UVM: add `// xsim-uvm: true`, or use common UVM tokens such as `uvm_pkg`, `` `uvm_``, or `run_test(...)`.

Build output is written under `.xsim/` in the workspace root and can be deleted safely.

## License

MIT. See `LICENSE`.
