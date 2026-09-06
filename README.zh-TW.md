# Philomatheia

[![驗證](https://github.com/Ch1nYu/philomatheia/actions/workflows/validate.yml/badge.svg)](https://github.com/Ch1nYu/philomatheia/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-open%20standard-blue.svg)](https://agentskills.io/)

**能為任何主題建立個人化課程，並跨 session 保存證據與精確進度的學習 Skill。**

[English](README.md)

Philomatheia 會把學習目標轉成可見的知識圖，用小型適應性循環教學，區分「看過、能解釋、有人引導能做、能獨立做、能遷移」，並把精確 checkpoint 保存到學習專案。它可以在任何從目錄載入 skill 的 agent harness 上執行，包含 Codex 與 Claude Code。

> 專案狀態：`v0.1.0` alpha。狀態模型、validator 與 installer 已測試；目前還沒有對照或長期研究能證明它會改善真實學習成果。

## 它解決什麼問題

| 常見學習流程 | Philomatheia |
|---|---|
| 依固定章節前進 | 從你的目標反推真正需要的先備知識主幹 |
| 上完課或答對一次就算完成 | 分開記錄回想、解釋、引導應用、獨立應用與遷移 |
| 依賴舊對話找進度 | 在專案內保存可自行理解的精確 checkpoint |
| 每個人使用同一路線 | 依實際證據調整 frontier、表示方式、提示與複習 |
| 課程假設看不見 | 為節點、關係和重要主張保留來源 |

它適合「真的想建立能力」的請求。一般資料搜尋、普通 code review、只要一次答案，或沒有學習目標的代做工作不會觸發。

## 快速開始

### 安裝

有 Node 18 以上就不需要 clone：

```sh
npx philomatheia
```

或者 clone 之後執行對應平台的 installer：

```powershell
# Windows
git clone https://github.com/Ch1nYu/philomatheia.git
Set-Location .\philomatheia
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

```sh
# macOS 或 Linux
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
sh ./install.sh
```

Installer 只複製執行時需要的檔案，而且在你選擇目標之前不會安裝任何東西。它會列出已知的 harness 與各自的目前狀態，再問你要裝到哪些：

```text
Select where to install philomatheia. Nothing is selected by default.

  1) Codex        /home/you/.agents/skills  installed
  2) Claude Code  /home/you/.claude/skills  detected, not installed
  3) Another directory (enter the path yourself)
```

| Harness | 目錄 |
|---|---|
| Codex | `$HOME/.agents/skills` |
| Claude Code | `$HOME/.claude/skills` |
| 其他 | 選最後一項，或用 `--dest-root` / `-DestinationRoot` 指定 |

直接按 Enter 代表不選任何目標，機器維持原狀。`--list` 或 `-ListTargets` 只印出同一份狀態表而不安裝，`--all` 或 `-All` 會選取所有已存在的 harness，`--dry-run` 或 `-WhatIf` 則預覽選定的目標路徑。若已存在同名 Skill，必須加上 `--update` / `-Update`，或在提示時確認替換，才會覆蓋。

`npx philomatheia` 在所有平台使用同一組參數：`npx philomatheia --list`、`--all`、`--update`、`--dry-run`、`--dest-root PATH`。手動安裝、release 壓縮檔與其他 harness 的做法請看 [INSTALL.md](INSTALL.md)。

### 開始一個學習專案

用獨立資料夾開啟你的 agent，然後輸入：

```text
使用 philomatheia skill。我想學統計學，目標是能批判性閱讀機器學習論文。我每週有四小時。請先判斷我的程度，再提出第一版知識圖路線讓我確認。
```

其他例子：

```text
教我在餐廳安全點餐所需的實用日文。我有嚴重花生過敏，請把語言練習與食品安全事實分開處理。
```

```text
從這個學習專案的精確 checkpoint 繼續。先問一題短回想，不要重教已完成內容。
```

支援明確呼叫的 harness 可以直接用名稱 `philomatheia` 啟動。當請求符合 [SKILL.md](SKILL.md) 的學習範圍時，它也會自動啟動。

## 運作方式

```text
目標與限制
    |
    v
經使用者核准的目標子圖與完成條件
    |
    v
2 至 3 個 active frontier 節點，負荷過高時縮成 1 個
    |
    v
回想 -> 解釋 -> 預測 -> 練習 -> 驗證 -> 整合
    |
    v
證據、mastery、複習與精確 checkpoint
    |
    +---------------------> 下一圈螺旋
```

每個學習專案會擁有自己的 `.philomatheia/`：

```text
.philomatheia/
|-- learning-state.json   機器可讀的唯一狀態來源
|-- LEARNING.md           給學習者閱讀的精簡投影
`-- artifacts/            選用的學習成果與證據
```

路線仍由學習者控制。修改目標、必要節點、目標 mastery 或完成條件時，必須重新確認；有證據支持的小型教學調整可自動進行。

## 「效果」目前能證明到哪裡

Philomatheia 的設計與 validator 可以驗證這些操作效果：

- 新 session 能從同一個待答問題繼續，不必重建舊對話；
- 使用大量提示後答對，不會被記成獨立 mastery；
- 高目標權重不能跳過未達標的 prerequisite；
- 新反證可以降低目前 mastery，同時保留歷史證據；
- 完成需要必要目標子圖與獨立整合任務同時通過；
- 來源衝突與未知內容會保留。

本專案沒有宣稱使用後一定能提高成績、縮短學習時間、取得專業能力或改善長期記憶。現有證據、可重跑的行為測試與長期驗證方法都寫在 [EVALUATION.md](EVALUATION.md)。

## 需求

- 任何從目錄載入 Agent Skills 的 agent harness，例如 Codex 或 Claude Code
- Python 3.10 以上，用於建立與驗證專案狀態
- 核心 Python scripts 不使用第三方套件
- Windows installer 需要 PowerShell 7；macOS/Linux 使用 POSIX shell
- 只有用 `npx` 安裝時才需要 Node.js 18 以上

若學習內容包含近期變化或專業資料，仍可能需要外部搜尋工具。

## 本機驗證

```sh
python scripts/check_package.py
python -m unittest discover -s tests -v
python -m py_compile scripts/init_project.py scripts/validate_state.py scripts/check_package.py
```

GitHub Actions 也會在 Windows、macOS 與 Linux 測試套件。

## Repository 結構

| 路徑 | 用途 |
|---|---|
| `SKILL.md` | 觸發邊界與核心學習流程 |
| `references/` | 知識圖、教學、證據、狀態、來源與領域規則 |
| `scripts/init_project.py` | 建立隔離狀態，拒絕覆寫現有專案 |
| `scripts/validate_state.py` | 檢查可由機器判斷的學習狀態 invariants |
| `assets/` | 初始 JSON 與 Markdown template |
| `agents/openai.yaml` | 提供給會讀取它的 harness 的選用顯示資訊 |
| `EVALUATION.md` | 現有證據、行為案例與成效驗證方法 |

## 啟發與授權

Philomatheia 受到 [`ai-engineering-from-scratch`](https://github.com/rohitg00/ai-engineering-from-scratch) 與 [ChongWen 的 Skill 設計筆記](https://www.chongwenz.cn/tech/AI/ai-skill-01/)啟發，並將概念延伸為使用者自訂的學習流程。套件不包含原課程的 lesson 或 quiz。

本專案採用 [MIT License](LICENSE)；貢獻同樣以此授權提供。
