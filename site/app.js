const translations = {
  zh: {
    'meta.title': 'Voke — 用手柄控制 Codex、ChatGPT 与你的 Mac',
    'meta.description': 'Voke：用游戏手柄控制 Codex、ChatGPT 与整个 Mac，并根据当前 App 自动切换专属映射。',
    'nav.download': '下载',
    'hero.title': '一只手柄，<br><em>控制每个 App。</em>',
    'hero.summary': '切到 Codex、ChatGPT 或其他 App，Voke 会自动换成对应的按键方案。新建任务、按住说话、模型选择和常用操作，抬手就能触发。',
    'hero.release': '当前版本 v0.4.0，新增前台 App 自动适配与 Codex / ChatGPT 专属动作。仍为测试版，安装时可能需要在“隐私与安全性”中选择仍要打开。',
    'controller.preview': 'Voke 手柄映射示意图',
    'controller.svg': '与 Voke 应用内一致的手绘 Pro Controller',
    'controller.status': 'CODEX 方案已启用',
    'controller.mappingLabel': 'CODEX · 当前映射',
    'controller.mappingAction': '新建任务 · ⌘N',
    'abilities.label': '主要功能',
    'abilities.routingTitle': '按 App 自动切换',
    'abilities.routingText': '每个 App 保存自己的按键方案。',
    'abilities.codexTitle': 'Codex / ChatGPT 动作',
    'abilities.codexText': '任务、语音、模型选择，直接映射。',
    'abilities.macTitle': '控制整个 Mac',
    'abilities.macText': '快捷键、鼠标、滚动与 App 切换。',
    'routing.title': '切到 Codex，<br>手柄就进入 <em>Codex 模式。</em>',
    'routing.summary': 'Voke 会识别当前前台 App，并自动载入它的专属方案。回到 ChatGPT、浏览器或其他软件时，同一组按键会立刻换回对应功能。',
    'routing.autoTitle': '自动切换，不用手动换配置',
    'routing.autoText': '手柄、外接键盘和鼠标按键都使用同一套路由。',
    'routing.syncTitle': 'Codex 快捷键自动同步',
    'routing.syncText': '你在 Codex 中修改快捷键，Voke 会读取并刷新，不用重复录入。',
    'routing.openTitle': '不锁死在某一个 App',
    'routing.openText': 'Codex / ChatGPT 是重点适配，其他 Mac App 也能建立专属方案。',
    'routing.consoleLabel': 'Codex 专属映射示例',
    'routing.foreground': '当前前台 App',
    'routing.follow': '自动跟随',
    'routing.dedicated': '专属方案',
    'routing.enabled': '已启用',
    'routing.otherApp': '其他 App',
    'routing.general': '通用方案',
    'routing.note': '部分高级动作需先在 Codex 的 Keyboard Shortcuts 中设置，Voke 会自动同步。',
    'actions.newTask': '新建任务',
    'actions.dictation': '按住说话',
    'actions.dictationDetail': '按下开始，松开结束',
    'actions.model': '模型与推理选择器',
    'actions.modelDetail': '选择模型和推理强度',
    'actions.approve': '接受修改',
    'actions.approveDetail': '处理当前等待请求',
    'start.title': '下载，拖入应用程序，<br>然后连接手柄。',
    'start.download': '下载 Voke-v0.4.0.dmg',
    'start.downloadText': '打开安装包，把 Voke 拖入“应用程序”。',
    'start.permission': '允许系统权限',
    'start.permissionText': '按应用引导开启辅助功能；测试版如被拦截，请在“隐私与安全性”中仍要打开。',
    'start.connect': '连接并设置手柄',
    'start.connectText': '点击手柄上的按钮，选择它要执行的动作。',
    'feedback.kicker': '还需要别的功能？',
    'feedback.title': '告诉我你想怎么控制。',
    'feedback.summary': '建议会直接送到 Voke，不需要 GitHub 账号。',
    'feedback.messageLabel': '你的想法 <i>必填</i>',
    'feedback.messagePlaceholder': '例如：我希望长按 ZR 时，右摇杆临时变成滚轮……',
    'feedback.nameLabel': '怎么称呼你 <i>可选</i>',
    'feedback.namePlaceholder': '名字或昵称',
    'feedback.contactLabel': '方便联系你吗 <i>可选</i>',
    'feedback.contactPlaceholder': '邮箱、微信或其他方式',
    'feedback.trap': '请留空',
    'feedback.statusIdle': '提交后我会认真看每一条。',
    'feedback.statusSending': '正在送达……',
    'feedback.statusSuccess': '收到了，谢谢你。这个建议已经送到 Voke。',
    'feedback.statusError': '提交失败，请稍后再试。',
    'feedback.submit': '提交功能建议',
  },
  en: {
    'meta.title': 'Voke — Control Codex, ChatGPT, and your Mac',
    'meta.description': 'Voke turns a game controller into an app-aware control surface for Codex, ChatGPT, and the rest of macOS.',
    'nav.download': 'Download',
    'hero.title': 'One controller.<br><em>Every app.</em>',
    'hero.summary': 'Move between Codex, ChatGPT, and the rest of your Mac. Voke loads the right profile automatically, putting new tasks, push-to-talk, model selection, and everyday actions under your fingers.',
    'hero.release': 'Voke v0.4.0 introduces foreground-app profiles and dedicated Codex / ChatGPT actions. This is still a test build and may require Open Anyway in Privacy & Security.',
    'controller.preview': 'Voke controller mapping preview',
    'controller.svg': 'Hand-drawn Pro Controller matching the Voke interface',
    'controller.status': 'CODEX PROFILE ACTIVE',
    'controller.mappingLabel': 'CODEX · CURRENT MAPPING',
    'controller.mappingAction': 'New task · ⌘N',
    'abilities.label': 'Core features',
    'abilities.routingTitle': 'App-aware switching',
    'abilities.routingText': 'Give every app its own control profile.',
    'abilities.codexTitle': 'Codex / ChatGPT actions',
    'abilities.codexText': 'Tasks, voice, and model selection on a button.',
    'abilities.macTitle': 'Control your whole Mac',
    'abilities.macText': 'Shortcuts, pointer, scrolling, and app switching.',
    'routing.title': 'Switch to Codex.<br>Your controller enters <em>Codex mode.</em>',
    'routing.summary': 'Voke detects the foreground app and loads its dedicated profile. Return to ChatGPT, a browser, or another app, and the same controls immediately take on the right role.',
    'routing.autoTitle': 'Switch automatically',
    'routing.autoText': 'Controllers, external keypads, and mouse buttons share the same routing system.',
    'routing.syncTitle': 'Sync Codex shortcuts',
    'routing.syncText': 'Change a shortcut in Codex and Voke refreshes it—no duplicate setup.',
    'routing.openTitle': 'Built for more than one app',
    'routing.openText': 'Codex / ChatGPT get dedicated support, while any Mac app can have its own profile.',
    'routing.consoleLabel': 'Codex profile example',
    'routing.foreground': 'Foreground app',
    'routing.follow': 'Auto-follow',
    'routing.dedicated': 'Dedicated profile',
    'routing.enabled': 'Active',
    'routing.otherApp': 'Other apps',
    'routing.general': 'General profile',
    'routing.note': 'Some advanced actions need a shortcut in Codex Keyboard Shortcuts first. Voke syncs it automatically.',
    'actions.newTask': 'New task',
    'actions.dictation': 'Push to talk',
    'actions.dictationDetail': 'Hold to speak, release to stop',
    'actions.model': 'Model & reasoning picker',
    'actions.modelDetail': 'Choose a model and reasoning level',
    'actions.approve': 'Approve change',
    'actions.approveDetail': 'Handle the pending request',
    'start.title': 'Download. Drag to Applications.<br>Connect your controller.',
    'start.download': 'Download Voke-v0.4.0.dmg',
    'start.downloadText': 'Open the disk image and drag Voke into Applications.',
    'start.permission': 'Grant system access',
    'start.permissionText': 'Follow the in-app Accessibility guide. If macOS blocks the test build, choose Open Anyway in Privacy & Security.',
    'start.connect': 'Connect and map',
    'start.connectText': 'Select a controller button and choose the action it should perform.',
    'feedback.kicker': 'Missing a control?',
    'feedback.title': 'Tell us how you want to use Voke.',
    'feedback.summary': 'Your idea goes straight to Voke—no GitHub account required.',
    'feedback.messageLabel': 'Your idea <i>Required</i>',
    'feedback.messagePlaceholder': 'For example: while holding ZR, temporarily turn the right stick into a scroll wheel…',
    'feedback.nameLabel': 'Your name <i>Optional</i>',
    'feedback.namePlaceholder': 'Name or nickname',
    'feedback.contactLabel': 'Can we contact you? <i>Optional</i>',
    'feedback.contactPlaceholder': 'Email, WeChat, or another contact',
    'feedback.trap': 'Leave blank',
    'feedback.statusIdle': 'Every suggestion is read carefully.',
    'feedback.statusSending': 'Sending…',
    'feedback.statusSuccess': 'Thank you—your idea has reached Voke.',
    'feedback.statusError': 'Could not send. Please try again later.',
    'feedback.submit': 'Send suggestion',
  },
};

const supportedLanguages = new Set(Object.keys(translations));
const savedLanguage = (() => {
  try { return localStorage.getItem('voke.language'); } catch { return null; }
})();
let currentLanguage = supportedLanguages.has(savedLanguage)
  ? savedLanguage
  : (navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en');

const translate = (key) => translations[currentLanguage][key] ?? translations.zh[key] ?? key;

function applyLanguage(language, persist = true) {
  if (!supportedLanguages.has(language)) return;
  currentLanguage = language;
  document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
  document.title = translate('meta.title');
  document.querySelector('meta[name="description"]')?.setAttribute('content', translate('meta.description'));

  document.querySelectorAll('[data-i18n]').forEach((element) => {
    element.textContent = translate(element.dataset.i18n);
  });
  document.querySelectorAll('[data-i18n-html]').forEach((element) => {
    element.innerHTML = translate(element.dataset.i18nHtml);
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach((element) => {
    element.setAttribute('placeholder', translate(element.dataset.i18nPlaceholder));
  });
  document.querySelectorAll('[data-i18n-aria]').forEach((element) => {
    element.setAttribute('aria-label', translate(element.dataset.i18nAria));
  });
  document.querySelectorAll('[data-lang]').forEach((button) => {
    const active = button.dataset.lang === language;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });

  if (persist) {
    try { localStorage.setItem('voke.language', language); } catch { /* Storage may be disabled. */ }
  }
}

document.querySelectorAll('[data-lang]').forEach((button) => {
  button.addEventListener('click', () => applyLanguage(button.dataset.lang));
});
applyLanguage(currentLanguage, false);

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    entry.target.classList.add('visible');
    observer.unobserve(entry.target);
  });
}, { threshold: 0.12 });

document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));

const feedbackForm = document.querySelector('#feedback-form');
const feedbackMessage = feedbackForm?.elements.message;
const feedbackCount = document.querySelector('#message-count');
const feedbackStatus = document.querySelector('#feedback-status');

function setFeedbackStatus(key, className = '') {
  feedbackStatus.dataset.i18n = key;
  feedbackStatus.className = `feedback-status${className ? ` ${className}` : ''}`;
  feedbackStatus.textContent = translate(key);
}

feedbackMessage?.addEventListener('input', () => {
  feedbackCount.textContent = String(feedbackMessage.value.length);
});

feedbackForm?.addEventListener('submit', async (event) => {
  event.preventDefault();

  const submitButton = feedbackForm.querySelector('button[type="submit"]');
  const formData = new FormData(feedbackForm);
  const payload = Object.fromEntries(formData.entries());

  submitButton.disabled = true;
  setFeedbackStatus('feedback.statusSending');

  try {
    const response = await fetch('/api/feedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!response.ok) throw new Error('feedback request failed');

    feedbackForm.reset();
    feedbackCount.textContent = '0';
    setFeedbackStatus('feedback.statusSuccess', 'success');
  } catch {
    setFeedbackStatus('feedback.statusError', 'error');
  } finally {
    submitButton.disabled = false;
  }
});
