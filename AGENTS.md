# AGENTS.md

## Project Overview

Philomatheia 是一個獨立的 Agent Skill，為任意主題建立可持續、以證據為基礎的學習專案。它用知識圖、漸進式教學循環、mastery evidence 與精確 checkpoint，讓新 session 能接續同一個學習狀態。

主要交付物是可安裝的 Skill runtime、project-local 狀態工具、跨平台安裝器、驗證測試與 release archive。

## Source Context

- Primary overview: `README.md` 與 `README.zh-TW.md`
- `SKILL.md`: 觸發邊界、學習契約、session loop 與寫入規則
- `EVALUATION.md`: 已有證據、行為案例與成效限制
- `INSTALL.md`: Codex、Windows、macOS 與 Linux 安裝方法
- `references/`: 知識圖、教學、mastery、state、來源與領域規則
- Remote: `https://github.com/Ch1nYu/philomatheia`

## Requirements

- 保持 Agent Skills 相容結構，`SKILL.md` frontmatter 的 `name` 必須與資料夾名稱一致。
- 每個學習專案的狀態只存在該專案的 `.philomatheia/`，不可自動跨專案共用 learner profile。
- `.philomatheia/learning-state.json` 是 machine-readable source of truth；`LEARNING.md` 是精簡投影。
- Mastery、route change 與 completion 必須受 evidence、prerequisite gate、approval fingerprint 與 integrative task 約束。
- 核心 scripts 支援 Python 3.10 以上，且不依賴第三方 Python package。
- 長期學習成效尚未經 controlled 或 longitudinal study 證實；不要擴大成效宣稱。

## Commands

- Windows install preview: `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf`
- Windows install/update: `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-Update]`
- POSIX install preview: `sh ./install.sh --dry-run`
- POSIX install/update: `sh ./install.sh [--update]`
- Package check: `python scripts/check_package.py`
- Test: `python -m unittest discover -s tests -v`
- Compile check: `python -m py_compile scripts/init_project.py scripts/validate_state.py scripts/check_package.py scripts/build_release.py`
- Build release: `python scripts/build_release.py`
- Lint: `Unknown`
- Typecheck: `Unknown`

上述 package、test、compile、installer 與 release commands 已由本機及 GitHub Actions 驗證。

## Structure

- `SKILL.md`: Skill 入口與不可違反的核心契約
- `agents/openai.yaml`: Codex 顯示資訊與 invocation policy
- `assets/`: 初始 state 與 learner-facing Markdown templates
- `references/`: 按需載入的教學與狀態規則
- `scripts/init_project.py`: 建立隔離的學習專案狀態
- `scripts/validate_state.py`: 驗證 machine-checkable state invariants
- `scripts/check_package.py`: 驗證公開套件結構與連結
- `scripts/build_release.py`: 產生 `dist/` release zip 與 SHA-256
- `tests/`: package 與 state tooling 的 unit tests
- `.github/workflows/`: 跨平台 validate 與 tag release automation

## Conventions

- 修改學習契約或 state schema 時，同步更新相關 reference、template、validator 與 tests。
- 英文與繁中 README 的功能、安裝方式與限制應保持一致。
- Installer 只部署 runtime allowlist；不可把 README、tests、GitHub metadata 或 package tooling 安裝到個人 Skill 目錄。
- `VERSION`、`CHANGELOG.md` 與 release tag 必須一致；tag 格式為 `vX.Y.Z`。
- `dist/` 是可重建產物，不提交 Git。

## Known Pitfalls

- Validator 只能證明狀態結構與 invariants，不能證明學習者真正理解或長期保留。
- 有提示的成功不能單獨證明 `independent_apply` 或 `transfer`。
- Major route payload 改變後必須更新 revision、重新取得使用者同意並重算 `approved_fingerprint`。
- Release workflow 只在 `v*` tag 觸發，且 tag 必須等於 `v$(cat VERSION)`。
- Runtime installer 的檔案集合刻意小於 repository；變更 allowlist 時必須同時測試「需要的檔案存在」與「repo-only 檔案未進入安裝結果」。

## Progress

- Current version: `0.1.0` alpha
- Package、state tools、Windows/POSIX installers 與跨平台 CI 已通過。
- Longitudinal learning-outcome evidence: `Unknown`
