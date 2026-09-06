# AGENTS.md

## Project Overview

Philomatheia 是一個獨立的 Agent Skill，為任意主題建立可持續、以證據為基礎的學習專案。它用知識圖、漸進式教學循環、mastery evidence 與精確 checkpoint，讓新 session 能接續同一個學習狀態。

主要交付物是可安裝的 Skill runtime、project-local 狀態工具、跨平台安裝器、驗證測試與 release archive。

## Source Context

- Primary overview: `README.md` 與 `README.zh-TW.md`
- `SKILL.md`: 觸發邊界、學習契約、session loop 與寫入規則
- `EVALUATION.md`: 已有證據、行為案例與成效限制
- `INSTALL.md`: 各 harness 的 skills 目錄、Windows/macOS/Linux 安裝與手動安裝方法
- `references/`: 知識圖、教學、mastery、state、來源與領域規則
- Remote: `https://github.com/Ch1nYu/philomatheia`

## Requirements

- 保持 Agent Skills 相容結構，`SKILL.md` frontmatter 的 `name` 必須與資料夾名稱一致。
- 不綁定單一 harness。文件、範例提示與安裝流程不得預設某一家 host 的呼叫語法或內建 installer；安裝路徑一律可由 `--dest-root` 或 `-DestinationRoot` 覆寫。
- 每個學習專案的狀態只存在該專案的 `.philomatheia/`，不可自動跨專案共用 learner profile。
- `.philomatheia/learning-state.json` 是 machine-readable source of truth；`LEARNING.md` 是精簡投影。
- Mastery、route change 與 completion 必須受 evidence、prerequisite gate、approval fingerprint 與 integrative task 約束。
- 核心 scripts 支援 Python 3.10 以上，且不依賴第三方 Python package。
- 長期學習成效尚未經 controlled 或 longitudinal study 證實；不要擴大成效宣稱。

## Commands

- Harness status (no install): `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ListTargets` / `sh ./install.sh --list`
- Windows install preview: `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf`
- Windows install/update: `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-Update]`
- POSIX install preview: `sh ./install.sh --dry-run`
- POSIX install/update: `sh ./install.sh [--update]`
- npx entry point: `node bin/philomatheia.js --list`
- npm package contents: `npm pack --dry-run --json`
- Package check: `python scripts/check_package.py`
- Test: `python -m unittest discover -s tests -v`
- Compile check: `python -m py_compile scripts/init_project.py scripts/validate_state.py scripts/check_package.py scripts/build_release.py`
- Build release: `python scripts/build_release.py`
- Lint: 無第三方 linter（刻意不引入 dependency）；等效 gate 為上方 package check、test 與 compile check
- Typecheck: 無第三方 type checker（同上理由）；`py_compile` 只保證語法正確

上述 package、test、compile、installer 與 release commands 已由本機及 GitHub Actions 驗證。

## Structure

- `SKILL.md`: Skill 入口與不可違反的核心契約
- `agents/openai.yaml`: 選用的顯示資訊與 invocation policy，只有會讀它的 harness 才使用
- `assets/`: 初始 state 與 learner-facing Markdown templates
- `references/`: 按需載入的教學與狀態規則
- `scripts/init_project.py`: 建立隔離的學習專案狀態
- `scripts/validate_state.py`: 驗證 machine-checkable state invariants
- `scripts/check_package.py`: 驗證公開套件結構與連結
- `scripts/build_release.py`: 產生 `dist/` release zip 與 SHA-256
- `bin/philomatheia.js`: `npx philomatheia` 進入點，只做平台判斷與參數轉換
- `package.json`: npm 發佈設定；`files` 決定使用者拿到什麼
- `tests/`: package、state tooling 與 installer 目標選擇的 unit tests
- `.github/workflows/`: 跨平台 validate 與 tag release automation

## Conventions

- 修改學習契約或 state schema 時，同步更新相關 reference、template、validator 與 tests。
- 英文與繁中 README 的功能、安裝方式與限制應保持一致。
- Installer 只部署 runtime allowlist；不可把 README、tests、GitHub metadata 或 package tooling 安裝到個人 Skill 目錄。
- `VERSION`、`package.json` 的 `version`、`CHANGELOG.md` 與 release tag 必須一致；tag 格式為 `vX.Y.Z`。
- `dist/`、`node_modules/`、`*.tgz` 是可重建產物，不提交 Git。
- `bin/philomatheia.js` 不重寫安裝邏輯；選單、偵測與複製只存在 `install.sh` 與 `install.ps1`。

## Known Pitfalls

- Validator 只能證明狀態結構與 invariants，不能證明學習者真正理解或長期保留。
- 有提示的成功不能單獨證明 `independent_apply` 或 `transfer`。
- Major route payload 改變後必須更新 revision、重新取得使用者同意並重算 `approved_fingerprint`。
- Release workflow 只在 `v*` tag 觸發，且 tag 必須等於 `v$(cat VERSION)`。
- Runtime installer 的檔案集合刻意小於 repository；變更 allowlist 時必須同時測試「需要的檔案存在」與「repo-only 檔案未進入安裝結果」。
- Installer 不會替使用者選 harness。未指定目標時它列出已知 harness 與狀態（`installed` / `detected, not installed` / `harness not found`）並詢問；直接 Enter 等於取消。無法互動的 session（pipe、CI、`PHILOMATHEIA_NON_INTERACTIVE=1`）不猜目標，會印出狀態表並以 exit code 2 結束，必須改用 `--dest-root` / `-DestinationRoot` 或 `--all` / `-All`。
- `--all` / `-All` 只選已存在的 harness，不會為不存在的 harness 建立目錄；一個都沒有時視為錯誤。
- 任一目標已存在且未加 `--update` 時，非互動流程在寫入前就整批中止；互動選擇時改為逐一詢問是否替換，拒絕即整批取消。
- PowerShell 用 `-File` 執行時不會拆解陣列參數；要一次指定多個 `-DestinationRoot` 必須改用 `-Command`（`bin/philomatheia.js` 已採用 `-Command`）。
- `pwsh -Command` 回傳的是自己的成敗，不是腳本的 exit code；shim 靠附加 `; exit $LASTEXITCODE` 才能把 2 傳出來。
- npx 在所有平台只提供 POSIX 風格參數。`install.ps1` 依 `PHILOMATHEIA_CLI=npx` 決定錯誤訊息要說 `--update` 還是 `-Update`；新增提到參數名稱的訊息時要一併處理。
- npm 的 `files` 是使用者實際拿到的檔案集合，和 `build_release.py` 的清單各自獨立；改動任一邊都要跑 `npm pack --dry-run` 與 package check。

## Progress

- Current version: `0.2.0` alpha
- Repository 自 `v0.1.0` 起已是 public；`v0.1.0` tag 已推上 origin。
- Package、state tools、Windows/POSIX installers 與跨平台 CI 已通過。
- Installer 改為互動選擇安裝目標，預設不安裝到任何 harness；`--list` / `--all` 供非互動使用。
- `npx philomatheia` 進入點已完成並通過端到端測試，但**尚未 publish 到 npm registry**。`0.1.0` 這個號碼已對應公開的 GitHub release，所以第一次 npm publish 走 `0.2.0`。
- `v0.2.0` 尚未 tag；`VERSION`、`package.json`、`CHANGELOG.md`、`CITATION.cff` 都已對齊 `0.2.0`。
- Release archive 只含 runtime scripts；`check_package.py` 與 `build_release.py` 留在 clone。
- Longitudinal learning-outcome evidence: 尚未建立，見 `EVALUATION.md` 的驗證協定
