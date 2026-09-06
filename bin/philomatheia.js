#!/usr/bin/env node
"use strict";

// One command surface for every platform. The selection prompt, harness
// detection, and file copying all live in install.sh and install.ps1; this
// shim only picks the right one and translates the flags.

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const packageRoot = path.resolve(__dirname, "..");

const USAGE = [
  "Usage: npx philomatheia [--dest-root PATH]... [--all] [--list] [--update] [--dry-run]",
  "",
  "Installs the Philomatheia skill into the agent skills directories you choose.",
  "No destination is used by default: with no --dest-root and no --all, the",
  "installer lists the known harnesses with their status and asks which to use.",
  "",
  "  --dest-root PATH  install into PATH; repeat for several directories",
  "  --all             install into every known harness directory that exists",
  "  --list            print the harness status table and exit",
  "  --update          replace an existing installation",
  "  --dry-run         print what would be installed and exit",
].join("\n");

function fail(message) {
  process.stderr.write(message + "\n" + USAGE + "\n");
  process.exit(2);
}

function parseArguments(argv) {
  const options = { destRoots: [], all: false, list: false, update: false, dryRun: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--dest-root") {
      index += 1;
      if (index >= argv.length) {
        fail("--dest-root needs a directory.");
      }
      options.destRoots.push(argv[index]);
    } else if (argument === "--all") {
      options.all = true;
    } else if (argument === "--list") {
      options.list = true;
    } else if (argument === "--update") {
      options.update = true;
    } else if (argument === "--dry-run") {
      options.dryRun = true;
    } else if (argument === "-h" || argument === "--help") {
      process.stdout.write(USAGE + "\n");
      process.exit(0);
    } else {
      fail("Unknown option: " + argument);
    }
  }
  return options;
}

function posixInvocation(options) {
  const args = [path.join(packageRoot, "install.sh")];
  for (const root of options.destRoots) {
    args.push("--dest-root", root);
  }
  if (options.all) args.push("--all");
  if (options.list) args.push("--list");
  if (options.update) args.push("--update");
  if (options.dryRun) args.push("--dry-run");
  return { command: "sh", args };
}

function quoteForPowerShell(value) {
  return "'" + String(value).replace(/'/g, "''") + "'";
}

function findPowerShell() {
  for (const candidate of ["pwsh", "powershell"]) {
    const probe = spawnSync(candidate, ["-NoProfile", "-Command", "exit 0"], {
      stdio: "ignore",
      windowsHide: true,
    });
    if (!probe.error && probe.status === 0) {
      return candidate;
    }
  }
  return null;
}

function windowsInvocation(options) {
  const shell = findPowerShell();
  if (!shell) {
    process.stderr.write(
      "PowerShell was not found. Install PowerShell 7, or run install.ps1 from a clone of the repository.\n"
    );
    process.exit(1);
  }
  // -File does not split array parameters, so the script is invoked through
  // -Command to keep several -DestinationRoot values working.
  const parts = ["&", quoteForPowerShell(path.join(packageRoot, "install.ps1"))];
  if (options.destRoots.length > 0) {
    parts.push("-DestinationRoot", options.destRoots.map(quoteForPowerShell).join(","));
  }
  if (options.all) parts.push("-All");
  if (options.list) parts.push("-ListTargets");
  if (options.update) parts.push("-Update");
  if (options.dryRun) parts.push("-WhatIf");
  // -Command reports its own success, not the script's, so the exit code has
  // to be handed back explicitly.
  parts.push("; exit $LASTEXITCODE");
  return {
    command: shell,
    args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", parts.join(" ")],
  };
}

function main() {
  const options = parseArguments(process.argv.slice(2));
  const invocation = process.platform === "win32" ? windowsInvocation(options) : posixInvocation(options);
  const result = spawnSync(invocation.command, invocation.args, {
    stdio: "inherit",
    windowsHide: true,
    // Tells the installer to name these flags, not its own platform's.
    env: Object.assign({}, process.env, { PHILOMATHEIA_CLI: "npx" }),
  });
  if (result.error) {
    process.stderr.write("Could not run the installer: " + result.error.message + "\n");
    process.exit(1);
  }
  process.exit(result.status === null ? 1 : result.status);
}

main();
