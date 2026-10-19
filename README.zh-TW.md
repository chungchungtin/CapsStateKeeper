# e04

[English](README.md) · 繁體中文

[作品網站](https://chungchungtin.github.io/CapsStateKeeper/) · [下載測試版](https://github.com/chungchungtin/CapsStateKeeper/releases/tag/v1.2.3-preview.1) · [回報問題](https://github.com/chungchungtin/CapsStateKeeper/issues)

**想打中文，卻打出一串英文？**

回中文訊息、輸入英文網址、切到另一個 App……每天切換中英文，常常打了一串才發現輸入法還停在上一個狀態。刪掉、切換、再重打，連剛才想說什麼都被打斷。

e04（原名 CapsStateKeeper）是給經常切換中英文的 Mac 使用者的小工具：打字時，在文字游標旁顯示目前的輸入法與 `abc / ABC`，讓你早一點發現切錯，少一點刪掉重打。

浮標不搶焦點、不擋滑鼠點擊；停止打字約 2 秒就會隱藏。另提供選單列 Caps Lock 狀態，並修復切回 ABC 時特定的 Caps Lock 不同步問題。

![原生浮標預覽](site/assets/native-indicator.png)

## 下載與安裝

提供 **macOS 14+ 通用版 DMG / ZIP**，支援 Apple Silicon 與 Intel，不需安裝 Swift 或 Xcode。

[下載 DMG](https://github.com/chungchungtin/CapsStateKeeper/releases/download/v1.2.3-preview.1/e04-v1.2.3-preview.1-universal.dmg) · [版本說明、ZIP 與 SHA-256](https://github.com/chungchungtin/CapsStateKeeper/releases/tag/v1.2.3-preview.1)

這是未經 Developer ID 簽章與 Apple 公證的測試版。將 App 拖到應用程式後啟動；若 macOS 無法驗證開發者，且你信任下載來源，請依 [Apple 官方說明](https://support.apple.com/zh-tw/102445) 為這個 App 選擇「強制打開」。浮標需要輔助使用權限，多鍵盤辨識使用輸入監控。

已有舊版時，先結束 App、備份，再替換原安裝位置的 App；尤其使用舊登入腳本的 `~/Applications/CapsStateKeeper.app` 應維持原位置，避免同時安裝兩份。偏好設定識別不變，權限可能需要重新允許。公開版不含本機開發更新程式，也不自動下載更新。[完整安裝說明](docs/INSTALL.txt)


## 功能

- **選單列狀態**：空心圖示表示 Caps Lock 關閉，實心圖示表示開啟。
- **打字浮標**：在打字處旁顯示輸入語言、輸入法與 `abc / ABC`，停止打字約 2 秒後自動隱藏。
- **浮標外觀**：背景與文字不透明度可分別調整，預設透明背景；浮標不取得焦點，滑鼠可直接穿透。
- **Caps Lock 同步**：切回 ABC 時，若鍵盤記住 Caps ON、實際打字旗標卻是 OFF，嘗試恢復 ON。支援辨識不同鍵盤；無法確認時不修改狀態。

## 建置與使用

需要 macOS 14 以上及 Swift 6 工具鏈。取得專案後建置：

```sh
git clone https://github.com/chungchungtin/CapsStateKeeper.git
cd CapsStateKeeper
./script/build_and_run.sh
```

App 顯示名稱為 **e04**；套件檔名仍為 `CapsStateKeeper.app`，以維持既有更新流程。

建置後會啟動 `dist/CapsStateKeeper.app`，點選選單列圖示即可操作：

| 選單 | 用途 |
| --- | --- |
| 打字時顯示浮標 | 開啟或關閉打字浮標 |
| 浮標設定 | 選擇是否跟隨文字游標，調整背景與文字不透明度 |
| 自動同步 Caps Lock | 記住開關選擇，重新啟動後維持設定；取消勾選不影響浮標 |
| 診斷與權限 | 查看偵測狀態、立即同步、重新啟動打字偵測或補齊權限 |
| 檢查本機更新… | 安裝這台 Mac 已建置的新版；有設定本機更新位置時才顯示 |
| 關於 e04 | 查看版本資訊 |

## 權限與隱私

| 權限 | 使用目的 |
| --- | --- |
| 輔助使用 | 偵測打字活動、讀取文字游標或輸入框的位置，並優先採用鍵盤事件的大小寫狀態 |
| 輸入監控 | 辨識送出切換輸入法快捷鍵的鍵盤，供多鍵盤同步使用 |

選單列 Caps Lock 圖示不依賴上述權限。浮標需要輔助使用權限；缺少權限時，可在「診斷與權限」補齊，授權完成後該提示會隱藏。無法辨識鍵盤且各鍵盤的 Caps 快取互相衝突時，不執行同步。

App 不保存、不記錄、不傳送輸入內容，也不建立網路連線或擷取螢幕。定位只讀取幾何資訊；安全鍵盤輸入期間隱藏浮標。事件處理範圍與同步條件見[開發說明](docs/DEVELOPMENT.md)。

## 開發者本機安裝與更新

長期使用並在登入時啟動：

```sh
./script/install.sh
```

App 安裝到 `~/Applications/CapsStateKeeper.app`。之後先建置新版，再從選單列選「檢查本機更新…」：

```sh
./script/build_and_run.sh build
```

也可開啟 `dist/更新 CapsStateKeeper.app`。更新程式會請你確認，備份舊版、保留浮標設定後重新啟動；失敗時嘗試回復。此流程使用本機套件，不從網路下載。備份存放在專案的 `.app-backups/`，更新記錄存放在 `~/Library/Logs/CapsStateKeeper/`。

移除 App 與登入項目：

```sh
./script/uninstall.sh
```

目前建置預設採用本機 ad-hoc 簽章，重新建置後 macOS 可能要求重新授權；公開測試版另由 `script/package-release.sh` 打包。

## 常見狀況

- **打字時沒有浮標**：確認「打字時顯示浮標」已勾選，再到「診斷與權限」查看原因。已授權但沒有打字訊號時，可選「重新啟動打字偵測」。
- **更新後權限失效**：結束 App，在系統設定的隱私權與安全性中重新加入並允許已安裝的 e04，再啟動 App。
- **浮標顯示「輸入框旁」或「滑鼠旁」**：目前 App 沒有提供精確游標位置，會改用輸入框或最後一次打字時的滑鼠位置；浮標不會持續跟隨滑鼠。
- **部分輸入法內部切換中英文沒有更新**：浮標依 macOS 的輸入來源通知顯示，無法保證辨識第三方輸入法未對系統公開的內部模式。`abc / ABC` 表示鍵盤配置下的英文字母大小寫，不預測文字欄位的自動大寫。

測試、外觀預覽及本機更新流程的細節見[開發說明](docs/DEVELOPMENT.md)。

## 回饋與授權

遇到問題可在 [GitHub Issues](https://github.com/chungchungtin/CapsStateKeeper/issues) 提供 macOS 版本、輸入法、使用的 App 與重現步驟。請避免貼上私人輸入內容。

採用 [MIT 授權](LICENSE)。
