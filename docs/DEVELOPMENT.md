# 開發說明

## 專案結構

本專案使用 Swift Package Manager，沒有外部套件依賴。

對外名稱為 **e04**（原名 CapsStateKeeper）。`CFBundleName`、`CFBundleDisplayName` 與介面使用新名稱；SwiftPM 產品名稱、套件檔名、Bundle ID、偏好設定、LaunchAgent 及更新路徑保留原識別，讓既有安裝與本機更新繼續相容。GitHub 與網站網址也保留原路徑。

| 目錄 | 職責 |
| --- | --- |
| `Sources/CapsStateCore` | 同步判斷、鍵盤快取選擇、打字活動、浮標幾何與偏好設定 |
| `Sources/CapsStateSystem` | 輸入來源、HID、唯讀鍵盤觀察及輔助使用定位 |
| `Sources/CapsStateUI` | AppKit 浮標、外觀選單及本機更新入口 |
| `Sources/CapsStateKeeper` | 選單列 App 與系統事件協調 |
| `Sources/CapsStateUpdater` | 獨立的本機更新 App |
| `script/Preview` | 使用固定範例資料產生浮標預覽 |

## 建置與檢查

```sh
# 建置 App 與更新程式，不啟動或安裝
./script/build_and_run.sh build

# 建置、啟動並確認程序存在
./script/build_and_run.sh --verify

# 自動測試
swift test

# 加上目前 Mac 的唯讀 HID 整合檢查
CAPS_STATE_KEEPER_INTEGRATION=1 swift test --filter HIDCapsLockControllerTests

# 固定資料的外觀預覽，不讀取桌面
swift run CapsIndicatorPreview dist/indicator-preview.png
# 公開展示素材：不含透明度檢查輔助線
swift run CapsIndicatorPreview dist/indicator-preview-clean.png --clean
swift run CapsIndicatorPreview dist/opacity-menu-preview.png --opacity-menu
```

`--debug`、`--logs` 與 `--telemetry` 可分別啟用除錯器、程序記錄及專案子系統記錄。平常使用 `./script/build_and_run.sh` 即可。

GitHub Actions 使用 macOS 執行測試與建置。兩項 HID 檢查需以環境變數明確啟用；ABC 配置檢查在系統未提供鍵盤輸入服務時標示略過。輸入服務不可用時的顯示及同步判斷另有獨立測試；此時使用一般輸入法標記，保留大小寫讀取，並停止 ABC 同步。

## Caps Lock 同步邊界

- 「自動同步 Caps Lock」使用 `CapsLockSynchronizationEnabled` 保存開關選擇。未設定時預設啟用；取消勾選後，重新啟動仍維持暫停，不影響浮標設定。
- 只處理 `com.apple.keylayout.ABC`，且必須同時滿足鍵盤的 `HIDCapsLockStateCache` 為 `true`、實際打字旗標為 `false`。
- 使用 `IOHIDSetModifierLockState` 恢復 ON，不合成按鍵。若 IOHIDSystem 已回報 ON、實際旗標仍是 OFF，會在確認打字旗標為 OFF 的前提下先寫 OFF，再恢復 ON。
- 不把鍵盤快取為 OFF 當成主動關閉 Caps Lock 的指令；目前同步策略只修復上述 ON 方向的不一致。
- `IOHIDManager` 辨識最近送出 Control-Space 的鍵盤。無法辨識且不同鍵盤快取互相衝突時，不猜測、不寫入。
- 有些鍵盤用 HID array 傳送 Space，無法在訂閱邊界只選 Space。因此先接收 keyboard-page usage，再立即過濾，只保留 Control／Space 的按下狀態及 Caps Lock 的變動通知；其他 usage 不進入狀態紀錄。

## 浮標與事件觀察

- 選單列與浮標共用經過濾的大小寫狀態。已獲輔助使用權限時優先使用唯讀鍵盤事件，僅取事件種類及修飾鍵旗標，不讀取字元或鍵碼、不保存事件或按鍵歷史。
- 尚未收到鍵盤事件時，約每 0.05 秒讀取硬體旗標，濾掉短暫的 Caps（120 ms）與 Shift（35 ms）變化；安全輸入期間清除舊的事件狀態。
- 打字偵測的備援只使用硬體事件累計數與距離最近 keyDown 的時間，仍受輔助使用權限與安全輸入狀態限制。備援排除快捷鍵及修飾鍵變動的不確定區間，並限頻重新建立事件觀察。
- 只在一般打字活動時叫出浮標。滑鼠操作、單獨 Caps／Shift、輸入法切換及 Command／Control／Fn 快捷鍵不會叫出或延長浮標。
- 閒置時不讀取游標或滑鼠位置。顯示期間約每 0.1 秒更新定位，依序使用文字游標、輸入框、最後一次打字時的滑鼠位置，並標示後兩種退回方式。
- 位置計算支援多螢幕，避開螢幕邊界、選單列與 Dock。切換 App／桌面、休眠、切換使用者及開啟 App 選單時，清除打字活動並隱藏浮標。
- 背景不透明度為 0–100%，文字為 20–100%。保留舊單一不透明度的讀取相容性，避免既有使用者的外觀設定被重設。

## 本機更新

建置腳本會產生主 App 與獨立更新 App，寫入版本、建置時間及內容指紋，完成簽章驗證後才替換 `dist` 產物。舊產物保留於 `.app-backups/`。

更新入口只讀取套件內明確設定的專案位置，不掃描電腦或雲端資料夾。專案移動後須在新位置重新建置。未設定本機更新位置的 App 不顯示更新選單。

圖形化更新與 `script/install.sh` 共用安裝流程：先複製、驗證新版，再停止舊版及替換，並檢查重新啟動。複製、驗證、停止或啟動失敗時會停止或嘗試回復，不把未確認的結果當作成功。同一時間只允許一個更新程序；保留既有登入設定及浮標偏好。

登入設定位於 `~/Library/LaunchAgents/com.zhongyongting.CapsStateKeeper.plist`。若已有程式碼簽章憑證，可透過 `CAPS_STATE_SIGNING_IDENTITY` 指定；腳本不會建立憑證或更改鑰匙圈信任。

## 公開原始碼的範圍

`.gitignore` 排除建置產物、App 備份、早期 Apple 問題回報資料，以及舊的「安裝浮動提示」捷徑。這些本機檔案仍保留，公開的使用入口以 README 為準。

目前腳本仍是本機建置工具，套件會包含建置機的專案路徑。公開二進位發佈應另行準備移除該路徑的發佈套件及簽章／公證流程；不要直接把整個專案資料夾或本機更新套件當成公開發佈包。
