# tmux-llm-usage（中文說明）

> 回到英文版：[README.md](../README.md)

**在狀態列顯示你的 AI / LLM 用量膠囊 — 資料來源自備。**

可在 macOS 與 Linux 執行，需要 [`jq`](https://jqlang.github.io/jq/) 與 POSIX
shell。開發與測試環境為 macOS + tmux `next-3.8`；因為整個插件只是 `sh` + `jq`，
tmux 跑得動的地方它都能跑。最低需求 tmux **1.8**。

這是「AI tmux 三件套」之一。另外兩個顯示 agent 正在「做什麼」，這個顯示你的
用量 / 額度 / 花費長什麼樣子。

## 這是什麼？

每個人的用量數字放在不同地方 — Claude Code 的 5 小時額度、自架 LiteLLM 的
花費總額、某個 API 計量儀表板、或你自己寫的腳本。沒有一個「通用數字」可以讓
插件替你爬，所以**它根本不爬**。它只給你兩樣東西：

1. **一份很小的契約。** 你把它指向*任何你自己寫的指令*，只要該指令在 stdout
   印出一小段 JSON：`{"v":1,"segments":[{"label":"CC 5H","value":"50%"}]}`。
2. **一個漂亮且不阻塞的狀態列段。** 插件會在背景照時間間隔跑你的指令、快取
   結果、再渲染進狀態列。就算你的指令很慢或離線，狀態列也不會卡 — 它會繼續
   顯示上一次的好值。

換句話說，這是一個**框架 + provider 契約**，不是爬蟲。你把*自己的*數字接進來
一次，它負責讓它好看、保持新鮮。

## 需求

- **tmux 1.8 以上。** 插件只用了非常老、非常穩定的 tmux 功能：使用者選項
  （`@…`）、`show-option`/`set-option` 的 `-g`/`-q`/`-v` 旗標、狀態列 `#()`
  指令、`display-message`。依官方
  [CHANGES](https://github.com/tmux/tmux/blob/master/CHANGES)，`@` 使用者選項與
  `-q` 旗標都在 tmux **1.8**（2013-03-26）加入；`-v`（只印值）在同一版即存在
  （1.8 的 `show-options` 接受 `-gqv`，arg spec 為 `gqst:vw`）。這才是真正的
  最低版本。實測於 tmux `next-3.8` — 新版寬鬆的預設值會遮蔽缺少的旗標，所以
  最低版本是對照 1.8 原始碼查證，而非本機 tmux。
- **`jq`**（`brew install jq` / `apt-get install jq`），用來解析 provider 的
  JSON。沒有 jq 時插件會提示一次，並顯示空白。

## 快速開始

> 沒用過 tmux 插件？**`prefix`** 指你的 tmux 前綴鍵，預設是 **`Ctrl-b`**
>（按住 Ctrl 再按 b，放開後再按下一個鍵）。若你改成 `Ctrl-a` 就用 `Ctrl-a`。

三件事：安裝插件、決定 `#{llm_usage}` 膠囊放狀態列哪裡、給它一個 provider 指令。

### 用 TPM（tmux 插件管理器，推薦）

1. 沒裝過 TPM 就先裝一次：

   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

2. 在 `~/.tmux.conf` 加入下列內容（`run '…/tpm'` 必須是檔案的**最後一行**）：

   ```tmux
   # 膠囊出現的位置 — 把 #{llm_usage} 放進狀態列任何地方：
   set -g status-right "#{llm_usage} | %H:%M"

   # provider：任何會印出用量 JSON 的指令。先用內建範例：
   set -g @llm-usage-provider "~/.tmux/plugins/tmux-llm-usage/examples/static.sh"

   set -g @plugin 'operonlab/tmux-llm-usage'
   run '~/.tmux/plugins/tpm/tpm'
   ```

3. 重新載入設定並安裝插件：

   ```sh
   tmux source-file ~/.tmux.conf     # 重新載入
   ```

   接著按 **`prefix` + I**（大寫 I）抓取插件。狀態列應該就會出現
   `CC 5H 50% · CC 7D 80% · CX 5H 12%`。把 `static.sh` 換成
   `examples/litellm.sh`、`examples/ccusage.sh` 或你自己的腳本即可顯示真實數字。

### 不用 TPM（純 `run-shell`）

```sh
git clone https://github.com/operonlab/tmux-llm-usage ~/.tmux/plugins/tmux-llm-usage
```

```tmux
set -g status-right "#{llm_usage} | %H:%M"
set -g @llm-usage-provider "~/.tmux/plugins/tmux-llm-usage/examples/static.sh"
run-shell '~/.tmux/plugins/tmux-llm-usage/llm-usage.tmux'
```

再重新載入：`tmux source-file ~/.tmux.conf`。

## provider（此選項會執行你的程式碼）

> ⚠️ **`@llm-usage-provider` 會執行 shell 指令。** 只在你信任的 `tmux.conf`
> 裡設定它 — 就跟你信任設定檔其他每一行一樣。插件會照刷新間隔以 `sh -c`
> 執行你給的字串。絕不要把它指向由不可信輸入拼出來的指令。

provider 是任何 stdout 為單一 JSON 物件的指令：

```json
{ "v": 1, "segments": [ { "label": "CC 5H", "value": "50%" } ] }
```

- `v` 是契約版本（`1`）；缺 `v` 視為 `1`。
- `segments` 是 `{ "label", "value" }` 的有序清單，只顯示前
  `@llm-usage-max-segments` 個。
- 印出空白 / 非零離開 / 壞掉的 JSON 時，膠囊只會保留上一次的好值，
  狀態列不會出現任何錯誤字串。

完整規格見 [provider-contract.md](provider-contract.md)，三個可改的範本在
[`../examples/`](../examples/)。**端點與金鑰放環境變數，不要寫進 provider 檔案。**

## 選項

在 `~/.tmux.conf` 的 `run` / `run-shell` 行**之前**設定。改完用
`tmux source-file ~/.tmux.conf` 重載。

| 選項 | 預設 | 說明 |
|---|---|---|
| `@llm-usage-provider` | *(無 — 必填)* | stdout 為契約 JSON 的指令。**會執行程式碼** — 見上方警告。未設 ⇒ 膠囊空白並提示一次。 |
| `@llm-usage-interval` | `60` | 背景刷新間隔（秒）。狀態列本身仍照 `status-interval` 更新，此值只限制 provider 實際被跑的頻率。 |
| `@llm-usage-format` | `label value` | 每段的模板。`label`、`value` 兩個字會被該段資料取代。可試 `[label:value]` 或 `#[fg=green]label#[default] value`。 |
| `@llm-usage-max-segments` | `4` | 最多顯示幾段（讓狀態列保持乾淨）。 |
| `@llm-usage-timeout` | `10` | 單次 provider 執行的上限秒數；超時就砍掉並保留上一次的值。 |

膠囊會出現在你於 `status-left` 或 `status-right` 放置字面 **`#{llm_usage}`**
的位置。沒放就不顯示。

## 移除

```sh
tmux run-shell ~/.tmux/plugins/tmux-llm-usage/scripts/teardown.sh
```

再把 `@plugin` / `set` / `run` 幾行從 `~/.tmux.conf` 刪掉。teardown 會把
`#{llm_usage}` 字面放回狀態列並刪除快取目錄，重複執行也安全。

## 疑難排解 / FAQ

**狀態列什麼都沒有。**
三個常見原因：(1) 沒把 `#{llm_usage}` 放進 `status-left` / `status-right`；
(2) `@llm-usage-provider` 沒設 — 插件載入時會提示；(3) 第一次渲染發生在第一次
背景刷新完成*之前*，膠囊會短暫空白。等一個 `status-interval`，或先跑一次
`scripts/usage.sh __sync__` 把快取暖起來。

**顯示「jq not found」。**
裝 jq（`brew install jq` / `apt-get install jq`）再重載。插件需要 jq 解析
provider 的 JSON。

**數字很舊 / 不更新。**
provider 只會每 `@llm-usage-interval` 秒（預設 60）重跑一次。若你的 provider
在失敗，插件會**刻意**保留上一次的好值而不是閃錯誤 — 自己在 shell 手動跑一次
provider 指令看它印什麼。它必須在 **stdout** 印出合法 JSON（log 請走 stderr）。

**以前用 `#(…)` 腳本狀態列會卡，這個會嗎？**
不會。這裡的 `#()` 只讀一個快取檔並立刻回傳；真正的 provider 在完全脫離的背景
程序裡跑。就算 provider 卡死也不會卡住狀態列。

## 授權

MIT — 見 [LICENSE](../LICENSE)。
