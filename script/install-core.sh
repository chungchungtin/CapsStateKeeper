#!/usr/bin/env bash
# Transactional local install. Functions are small seams for isolated tests;
# production callers use the fixed app/LaunchAgent paths from install.sh.

caps_info() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"; }
caps_validate_app() {
  [[ -d "$1" && ! -L "$1" && -x "$1/Contents/MacOS/CapsStateKeeper" ]] || return 1
  [[ "$(caps_info "$1" CFBundleIdentifier)" == "com.zhongyongting.CapsStateKeeper" ]] || return 1
  [[ "$(caps_info "$1" CFBundleExecutable)" == "CapsStateKeeper" ]] || return 1
  /usr/bin/codesign --verify --deep --strict "$1" || return 1
  if [[ -n "$2" ]]; then
    [[ "$(caps_info "$1" CapsStateKeeperBuildID)" == "$2" ]] || return 1
  fi
}
caps_copy_app() { /usr/bin/ditto "$1" "$2"; }
caps_service_loaded() { /bin/launchctl print "$1/com.zhongyongting.CapsStateKeeper" >/dev/null 2>&1; }
caps_stop_service() { /bin/launchctl bootout "$1/com.zhongyongting.CapsStateKeeper"; }
caps_stop_app() {
  local result=0
  /usr/bin/pkill -x CapsStateKeeper || result=$?
  [[ "$result" -le 1 ]] || return "$result"
  for _ in {1..40}; do
    result=0
    /usr/bin/pgrep -x CapsStateKeeper >/dev/null || result=$?
    [[ "$result" -eq 1 ]] && return 0
    [[ "$result" -eq 0 ]] || return "$result"
    sleep 0.1
  done
  echo "程式未能正常結束，未替換安裝中的 App。" >&2
  return 1
}
caps_start_service() {
  /bin/launchctl bootstrap "$1" "$2" || return 1
  for _ in {1..40}; do
    if /bin/launchctl print "$1/com.zhongyongting.CapsStateKeeper" 2>/dev/null |
       /usr/bin/awk '/^[[:space:]]*pid = [1-9][0-9]*/ { found=1 } END { exit !found }'; then
      return 0
    fi
    sleep 0.1
  done
  echo "新版尚未確認啟動，將嘗試回復舊版。" >&2
  return 1
}

caps_install_update() (
  set -eEuo pipefail
  local source="$1" installed="$2" agent="$3" backups="$4" domain="$5" expected="${6:-}"
  local destination="$(dirname "$installed")" lock stage backup
  local had_service=false stopped_service=false moved_old=false placed_new=false created_agent=false
  [[ "$source" = /* && "$installed" = /* && "$agent" = /* && "$backups" = /* ]] || exit 2
  [[ "$(basename "$installed")" == CapsStateKeeper.app && "$source" != "$installed" ]] || exit 2
  [[ "$(basename "$agent")" == com.zhongyongting.CapsStateKeeper.plist ]] || exit 2
  [[ ! -L "$installed" && ! -L "$agent" ]] || exit 2
  [[ -z "$expected" || "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || exit 2
  caps_validate_app "$source" "$expected"
  if [[ -e "$installed" ]]; then
    [[ "$(caps_info "$installed" CFBundleIdentifier)" == com.zhongyongting.CapsStateKeeper ]] || exit 2
    [[ "$(caps_info "$installed" CFBundleExecutable)" == CapsStateKeeper ]] || exit 2
  fi
  mkdir -p "$destination" "$(dirname "$agent")" "$backups"
  lock="$destination/.CapsStateKeeper-update.lock"
  [[ ! -L "$lock" && ( ! -e "$lock" || -f "$lock" ) ]] || exit 2
  exec 9>>"$lock"
  if ! /usr/bin/lockf -s -t 0 9; then
    echo "另一個更新可能仍在進行中，請稍候再試。鎖定位置：$lock" >&2
    exit 1
  fi
  # The kernel lock lives on descriptor 9, not a PID marker. It is released on
  # every exit, including crashes. Keep the file to avoid lock/unlink races.
  stage="$(mktemp -d "$destination/.CapsStateKeeper-stage.XXXXXX")"
  backup="$(mktemp -d "$backups/install-$(date +%Y%m%d-%H%M%S).XXXXXX")"

  caps_recover() {
    local result=$?
    trap - ERR
    set +e
    if $placed_new; then
      if caps_service_loaded "$domain"; then caps_stop_service "$domain"; fi
      if ! caps_stop_app; then
        echo "無法停止更新中的程式；未進一步搬動檔案。舊版備份：$backup" >&2
        exit "$result"
      fi
      if ! mv "$installed" "$backup/failed-new-CapsStateKeeper.app"; then
        echo "無法隔離新版；未覆寫任何 App。舊版備份：$backup/CapsStateKeeper.app" >&2
        exit "$result"
      fi
    fi
    if $moved_old; then
      if ! mv "$backup/CapsStateKeeper.app" "$installed"; then
        echo "自動回復未完成。舊版仍保留在：$backup/CapsStateKeeper.app" >&2
        exit "$result"
      fi
      echo "已回復舊版 App。"
    fi
    if $created_agent; then mv "$agent" "$backup/failed-new-LaunchAgent.plist"; fi
    if $had_service && $stopped_service; then
      if ! caps_start_service "$domain" "$agent"; then
        echo "舊版已保留，但無法確認重新啟動。請開啟：$installed" >&2
      fi
    fi
    echo "更新未完成。備份：$backup；暫存：$stage" >&2
    exit "$result"
  }
  trap caps_recover ERR

  # Fully copy and validate before touching the installed executable.
  caps_copy_app "$source" "$stage/CapsStateKeeper.app"
  caps_validate_app "$stage/CapsStateKeeper.app" "$expected"
  if [[ -f "$agent" ]]; then
    /usr/bin/plutil -lint "$agent" >/dev/null
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :Label' "$agent")" == com.zhongyongting.CapsStateKeeper ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$agent")" == "$installed/Contents/MacOS/CapsStateKeeper" ]]
    cp -p "$agent" "$backup/com.zhongyongting.CapsStateKeeper.plist"
  else
    /usr/bin/plutil -create xml1 "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert Label -string com.zhongyongting.CapsStateKeeper "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert ProgramArguments -array "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$installed/Contents/MacOS/CapsStateKeeper" "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert RunAtLoad -bool true "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert KeepAlive -dictionary "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert KeepAlive.SuccessfulExit -bool false "$stage/LaunchAgent.plist"
    /usr/bin/plutil -insert ProcessType -string Interactive "$stage/LaunchAgent.plist"
  fi
  if caps_service_loaded "$domain"; then
    had_service=true
    caps_stop_service "$domain"
    stopped_service=true
  fi
  caps_stop_app
  if [[ -e "$installed" ]]; then
    mv "$installed" "$backup/CapsStateKeeper.app"
    moved_old=true
  fi
  mv "$stage/CapsStateKeeper.app" "$installed"
  placed_new=true
  caps_validate_app "$installed" "$expected"
  if [[ ! -f "$agent" ]]; then
    mv "$stage/LaunchAgent.plist" "$agent"
    created_agent=true
  fi
  caps_start_service "$domain" "$agent"
  trap - ERR
  rmdir "$stage"
  echo "更新完成，已確認程式啟動：$installed"
  echo "舊版備份：$backup"
)
