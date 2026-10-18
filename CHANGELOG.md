# e04 v1.2.2-preview.2

CapsStateKeeper 現在叫做 **e04**。打了一串才發現沒切中文，那個當下的心聲，就是新名字。

- App 選單、關於視窗及本機更新介面改用 e04；App 版本為 1.2.2（build 7）。
- 中英文網站與 README 同步更新名稱，保留既有公開網址。
- 保留 Bundle ID、偏好設定、安裝檔名與更新路徑，延續既有安裝相容性。
- 輸入法提示、大小寫顯示、Caps Lock 同步與多鍵盤支援維持原有行為。

這仍是 **原始碼預覽版**，需要 macOS 14+ 與 Swift 6 自行建置，尚未提供經 Apple 公證的安裝檔。

[作品網站](https://chungchungtin.github.io/CapsStateKeeper/) · [繁體中文建置說明](https://github.com/chungchungtin/CapsStateKeeper/blob/main/README.zh-TW.md) · [English guide](https://github.com/chungchungtin/CapsStateKeeper/blob/main/README.md)

---

CapsStateKeeper is now **e04**. This source preview updates the app's display name, menu and updater text, website, and README. Existing identifiers, preferences, install paths, and public URLs remain compatible. Build with Swift 6 on macOS 14 or later; no notarized installer is included.

---

# CapsStateKeeper v1.2.2-preview.1

想打中文，卻打出一串英文？CapsStateKeeper 在 Mac 打字處顯示目前輸入法與大小寫，幫你及早發現切錯，少一點刪掉重打。

這是首次公開的原始碼預覽版。需要 macOS 14+ 與 Swift 6 自行建置；目前沒有經 Apple 公證、可直接安裝的 App。

## 內容

- 打字時顯示目前輸入法與 `abc / ABC`，停止約 2 秒後自動隱藏。
- 浮標不搶焦點，滑鼠點擊可穿透；可調整背景與文字透明度。
- 保留多鍵盤支援，修復切回 ABC 時特定的 Caps Lock 不同步狀況。
- 精簡選單，並修正自動同步開關無法跨次啟動保存的問題。
- 系統暫時沒有輸入來源時顯示一般標記，保留大小寫讀取，避免空值造成中止。
- 加入中英文網站與專案說明，採用 MIT 授權。

## 試用

[作品網站](https://chungchungtin.github.io/CapsStateKeeper/) · [繁體中文建置說明](https://github.com/chungchungtin/CapsStateKeeper/blob/main/README.zh-TW.md) · [English guide](https://github.com/chungchungtin/CapsStateKeeper/blob/main/README.md)

下載本頁原始碼，或複製專案後依 README 建置。App 選單目前為繁體中文；浮標需要輔助使用權限，多鍵盤辨識使用輸入監控權限。本機建置採用 ad-hoc 簽章，重新建置後可能需要重新授權。

本機 109 項測試通過，包含 2 項唯讀 HID 整合檢查；建置、簽章與啟動檢查通過。這仍是早期預覽版，實際打字、不同 App 及多鍵盤組合仍需要更多驗證。第三方輸入法未對 macOS 公開的內部中英文模式可能無法辨識。

遇到問題請在 [Issues](https://github.com/chungchungtin/CapsStateKeeper/issues) 留下 macOS 版本、輸入法、使用的 App 與重現步驟。

---

First public source preview. Build with Swift 6 on macOS 14 or later. The app shows the active input method beside your typing position, hides when idle, and preserves targeted Caps Lock synchronization with multi-keyboard support. Menus are currently in Traditional Chinese. There is no notarized installer in this release. Licensed under MIT.
