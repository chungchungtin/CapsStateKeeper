"use strict";

(() => {
  const $ = (selector) => document.querySelector(selector);
  const all = (selector) => [...document.querySelectorAll(selector)];
  const originals = new Map(all("[data-i18n]").map((node) => [node, node.textContent]));
  const originalAria = new Map(all("[data-aria]").map((node) => [node, node.getAttribute("aria-label")]));
  const originalAlt = new Map(all("[data-alt]").map((node) => [node, node.alt]));
  const english = {
    skip: "Skip to content", navFeatures: "Features", navPrivacy: "Privacy", navGet: "Get the app",
    audience: "For Mac users who switch between Chinese and English",
    heading1: "Typing Chinese?", heading2: "Still in English?",
    lead1: "A Chinese message. An English URL. Another input-method switch.", lead2: "You type a string of characters, notice the wrong mode, delete it, and start again. There goes your train of thought.",
    solution: "CapsStateKeeper shows your current input method where you type, so you can catch a wrong mode sooner and retype less.",
    demoLink: "See the reminder", permissionsLink: "Permissions & privacy", platform: "macOS 14+ · A native macOS utility",
    documentTitle: "Today's notes", modeZh: "Zhuyin", modeUpper: "ABC uppercase",
    demoCaption: "Interactive illustration · not a screen recording",
    feature1: "Less deleting and retyping", feature1Text: "See the active input method as you type and catch a Chinese/English mismatch sooner.",
    feature2: "Less looking away", feature2Text: "Your input method and letter case appear where you type, keeping your eyes on your words.",
    feature3: "Fewer interruptions", feature3Text: "The indicator never takes focus, lets clicks pass through, and hides about 2 seconds after typing stops.",
    privacyTitle1: "Clear permissions.", privacyTitle2: "Fewer unknowns.",
    privacyIntro1: "The app does not store what you type", privacyIntro2: "or make network connections.",
    nativeTitle: "The native indicator", nativeCaption: "Rendered by the app with fixed sample data",
    accessibility: "Accessibility", accessibilityText: "Detects typing activity and locates the text cursor or input field.",
    inputMonitoring: "Input Monitoring", inputMonitoringText: "Identifies the keyboard used to switch input sources for multi-keyboard synchronization.",
    secureInput: "The indicator hides while Secure Keyboard Entry is active.",
    limitsTitle: "Scope and limitations",
    limit1: "If an app does not expose a cursor location, the indicator falls back to the input field or the mouse position at the last typing event.",
    limit2: "Caps Lock synchronization handles one case when returning to ABC: a keyboard remembers ON while the typing flag is OFF. If the keyboard cannot be identified and keyboard states conflict, no change is made.",
    limit3: "Internal language switches in third-party input methods may not be detectable if they are not reported to macOS. The app's menus are currently in Traditional Chinese.",
    privacyMore: "More about privacy",
    privacyMore1: "The app does not log typed text, capture the screen, or retain keystroke history. Positioning reads geometry only. The local updater uses packages already built on your Mac.",
    privacyMore2: "This page has no analytics, external fonts, or sign-up forms. The demo uses fixed examples and does not read your keyboard or input-source state.",
    setupTitle: "Start on your Mac.", setupIntro1: "Build from source for now.", setupIntro2: "A ready-to-install release is being prepared.",
    commandCaption: "Run in the project directory", copy: "Copy", buildLink: "Build instructions", buildTitle: "Build and first launch",
    build1: "Requires macOS 14 or later and a Swift 6 toolchain.",
    build2: "After obtaining the source, run the command above in the project directory. The menu-bar app opens when the build finishes. Enable Accessibility and Input Monitoring as needed.",
    build3: "Current builds use local signing; macOS may require you to grant permissions again after rebuilding. A public installer is still in preparation.",
    readmeLink: "Read the full project guide (English)", readmeZhLink: "Read the full project guide (繁體中文)",
    sourceProject: "View on GitHub", sourceRelease: "Download source preview", feedbackLink: "Report an issue",
    download: "Download app (coming soon)", footerLine: "Less retyping. More room for your thoughts.", privacyLink: "Privacy",
    nav: "Main navigation", demoAria: "Interactive input-state demo", modeAria: "Demo input state", featuresAria: "Main features",
    nativeAlt: "Four native AppKit indicators showing ABC, Zhuyin, and lowercase or uppercase on light and dark backgrounds"
  };
  const samples = {
    zh: {language: "中", source: "注音", description: "中文", letters: "abc", caseName: "小寫", text: "寫下想法，少一點打斷。", subline: "Keep your thoughts flowing."},
    en: {language: "EN", source: "ABC", description: "英文", letters: "abc", caseName: "小寫", text: "Keep your thoughts flowing.", subline: "讓輸入狀態，跟上你的想法。"},
    upper: {language: "EN", source: "ABC", description: "英文", letters: "ABC", caseName: "大寫", text: "ONE LESS THING TO CHECK.", subline: "輸入法與英文字母大小寫，一眼確認。"}
  };
  let lang = new URL(location.href).searchParams.get("lang") === "en" ? "en" : "zh-TW";
  let mode = "zh";
  let phase = "idle";
  let elapsed = 0;
  let previousFrame = 0;
  let frame = 0;
  let hideTimer = 0;
  let lastStatus = "";
  let isManual = false;
  let copyResult = "";
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
  const t = (zh, en) => lang === "en" ? en : zh;

  function status(text) {
    if (lastStatus !== text) { $("#demo-status").textContent = text; lastStatus = text; }
  }
  function setMode(next) {
    mode = next;
    const sample = samples[mode];
    $("#badge-language").textContent = sample.language;
    $("#badge-source").textContent = sample.source;
    $("#badge-description").textContent = sample.description;
    $("#badge-case").textContent = sample.letters;
    $("#badge-case-name").textContent = sample.caseName;
    $("#sample-text").textContent = sample.text;
    $("#sample-subline").textContent = sample.subline;
    $("#indicator").classList.toggle("uppercase", mode === "upper");
    all("[data-mode]").forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.mode === mode)));
  }
  function controls() {
    $("#play").setAttribute("aria-pressed", String(phase === "playing"));
    $("#play-icon").textContent = phase === "playing" ? "Ⅱ" : "▶";
    $("#play-label").textContent = phase === "playing" ? t("暫停示範", "Pause demo") : phase === "paused" ? t("繼續示範", "Resume demo") : phase === "finished" ? t("重新播放", "Replay demo") : t("播放示範", "Play demo");
  }
  function renderStatus() {
    if (phase === "playing" || phase === "paused") {
      const scene = elapsed < 6 ? t("注音輸入", "Typing with Zhuyin") : elapsed < 12 ? t("英文小寫", "Typing lowercase English") : elapsed < 16 ? t("英文大寫", "Typing uppercase English") : elapsed < 18 ? t("停止打字", "Typing stopped") : t("浮標自動隱藏", "Indicator hidden");
      status(`${phase === "paused" ? t("已暫停 · ", "Paused · ") : ""}${scene} · ${Math.min(20, Math.floor(elapsed))} / 20 ${t("秒", "s")}`);
    } else if (phase === "finished") {
      status(t("示範結束：停止打字約 2 秒後，浮標隱藏。", "Demo complete: the indicator hides about 2 seconds after typing stops."));
    } else if (isManual) {
      const name = mode === "zh" ? t("注音", "Zhuyin") : mode === "en" ? t("英文小寫", "English lowercase") : t("英文大寫", "English uppercase");
      status(`${name}${t("示範；停止打字約 2 秒後隱藏。", " demo; hides about 2 seconds after typing stops.")}`);
    } else {
      status(t("選擇一個輸入狀態，或播放 20 秒示範。", "Choose an input state, or play the 20-second demo."));
    }
  }
  function renderPlayback() {
    const nextMode = elapsed < 6 ? "zh" : elapsed < 12 ? "en" : "upper";
    setMode(nextMode);
    const start = elapsed < 6 ? 0 : elapsed < 12 ? 6 : 12;
    const duration = nextMode === "upper" ? 3.4 : 4.7;
    const progress = Math.min(1, (elapsed - start) / duration);
    const letters = [...samples[nextMode].text];
    $("#sample-text").textContent = reducedMotion.matches ? samples[nextMode].text : letters.slice(0, Math.max(0, Math.ceil(letters.length * progress))).join("");
    $("#indicator").classList.toggle("is-hidden", elapsed >= 18);
    renderStatus();
  }
  function tick(timestamp) {
    if (phase !== "playing") return;
    if (previousFrame) elapsed = Math.min(20, elapsed + (timestamp - previousFrame) / 1000);
    previousFrame = timestamp;
    renderPlayback();
    if (elapsed >= 20) {
      phase = "finished";
      controls();
      renderStatus();
    } else frame = requestAnimationFrame(tick);
  }
  function pause() {
    phase = "paused";
    cancelAnimationFrame(frame);
    previousFrame = 0;
    controls();
    renderStatus();
  }
  function showCopyStatus() {
    $("#copy-status").textContent = copyResult === "success" ? t("已複製建置指令。", "Build command copied.") : copyResult === "manual" ? t("請選取上方指令，手動複製。", "Select the command above and copy it manually.") : "";
  }
  function applyLanguage() {
    document.documentElement.lang = lang;
    originals.forEach((value, node) => { node.textContent = lang === "en" ? english[node.dataset.i18n] ?? value : value; });
    originalAria.forEach((value, node) => node.setAttribute("aria-label", lang === "en" ? english[node.dataset.aria] ?? value : value));
    originalAlt.forEach((value, node) => { node.alt = lang === "en" ? english[node.dataset.alt] ?? value : value; });
    $("#language").textContent = lang === "en" ? "繁中" : "EN";
    $("#footer-language").textContent = lang === "en" ? "繁體中文" : "English";
    [$("#language"), $("#footer-language")].forEach((button) => button.setAttribute("aria-label", t("Switch to English", "切換為繁體中文")));
    document.title = t("CapsStateKeeper — 想打中文，卻打出英文？", "CapsStateKeeper — Typing Chinese? Still in English?");
    $("meta[name=description]").content = t("想打中文，卻打出英文？CapsStateKeeper 在 Mac 的打字處顯示目前輸入法與大小寫，讓你早一點發現中英文切錯，少一點刪掉重打與思緒中斷。", "Meant to type Chinese but got English instead? CapsStateKeeper shows your active input method where you type on macOS, helping you catch a wrong mode sooner and retype less.");
    $("meta[property=\"og:title\"]").content = document.title;
    $("meta[property=\"og:description\"]").content = $("meta[name=description]").content;
    $("meta[property=\"og:locale\"]").content = lang === "en" ? "en_US" : "zh_TW";
    controls();
    renderStatus();
    showCopyStatus();
  }
  function switchLanguage() {
    lang = lang === "en" ? "zh-TW" : "en";
    applyLanguage();
    try {
      const url = new URL(location.href);
      if (lang === "en") url.searchParams.set("lang", "en"); else url.searchParams.delete("lang");
      history.replaceState(null, "", url);
    } catch { /* Language switching also works when opened as a local file. */ }
  }
  all("[data-mode]").forEach((button) => button.addEventListener("click", () => {
    cancelAnimationFrame(frame);
    clearTimeout(hideTimer);
    phase = "idle";
    elapsed = 0;
    previousFrame = 0;
    isManual = true;
    setMode(button.dataset.mode);
    $("#indicator").classList.remove("is-hidden");
    controls();
    renderStatus();
    hideTimer = setTimeout(() => $("#indicator").classList.add("is-hidden"), 2000);
  }));
  $("#play").addEventListener("click", () => {
    clearTimeout(hideTimer);
    if (phase === "playing") { pause(); return; }
    if (phase !== "paused") elapsed = 0;
    phase = "playing";
    previousFrame = 0;
    isManual = false;
    controls();
    renderPlayback();
    frame = requestAnimationFrame(tick);
  });
  $("#language").addEventListener("click", switchLanguage);
  $("#footer-language").addEventListener("click", switchLanguage);
  document.addEventListener("visibilitychange", () => { if (document.hidden && phase === "playing") pause(); });
  $("#build-guide-link").addEventListener("click", () => { $("#build-guide").open = true; });
  $("#copy-command").addEventListener("click", async () => {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText("./script/build_and_run.sh");
      copyResult = "success";
    } catch {
      copyResult = "manual";
    }
    showCopyStatus();
  });
  applyLanguage();
})();
