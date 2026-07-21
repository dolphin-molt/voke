const loginStage = document.querySelector('#login-stage');
const loginForm = document.querySelector('#login-form');
const loginStatus = document.querySelector('#login-status');
const dashboard = document.querySelector('#dashboard');
const headerActions = document.querySelector('#header-actions');
const feedbackList = document.querySelector('#feedback-list');
const inboxStatus = document.querySelector('#inbox-status');
const feedbackTemplate = document.querySelector('#feedback-template');
const filters = document.querySelector('#filters');
const refreshButton = document.querySelector('#refresh-button');
const logoutButton = document.querySelector('#logout-button');

const statusLabels = { new: '新反馈', reviewing: '处理中', done: '已完成' };
let activeStatus = 'all';

const request = async (url, options = {}) => {
  const response = await fetch(url, {
    credentials: 'same-origin',
    ...options,
    headers: {
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  });

  const contentType = response.headers.get('content-type') || '';
  const data = contentType.includes('application/json') ? await response.json() : null;
  if (!response.ok) {
    const error = new Error(data?.message || '请求没有完成，请稍后再试。');
    error.status = response.status;
    throw error;
  }
  return data;
};

const showLogin = (message = '') => {
  loginStage.hidden = false;
  dashboard.hidden = true;
  headerActions.hidden = true;
  loginStatus.textContent = message;
};

const showDashboard = () => {
  loginStage.hidden = true;
  dashboard.hidden = false;
  headerActions.hidden = false;
};

const localTime = (isoTime) => {
  const date = new Date(isoTime);
  if (Number.isNaN(date.getTime())) return isoTime;
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

const emptyState = () => {
  const node = document.createElement('div');
  node.className = 'empty';
  node.innerHTML = '<div><span>⌁</span><b>这里暂时是空的</b><p>符合当前状态的反馈会出现在这里。</p></div>';
  return node;
};

const updateFeedback = async (id, status, card) => {
  const buttons = card.querySelectorAll('.status-actions button');
  buttons.forEach((button) => { button.disabled = true; });

  try {
    await request('/api/admin/update', {
      method: 'POST',
      body: JSON.stringify({ id, status }),
    });
    await loadFeedback();
  } catch (error) {
    if (error.status === 401) return showLogin('登录已过期，请重新输入密码。');
    inboxStatus.textContent = error.message;
    inboxStatus.className = 'inbox-status error';
    buttons.forEach((button) => { button.disabled = false; });
  }
};

const renderFeedback = (items) => {
  feedbackList.replaceChildren();
  if (!items.length) {
    feedbackList.append(emptyState());
    return;
  }

  for (const item of items) {
    const card = feedbackTemplate.content.firstElementChild.cloneNode(true);
    card.dataset.status = item.status;
    card.querySelector('time').textContent = localTime(item.created_at);
    card.querySelector('time').dateTime = item.created_at;
    card.querySelector('.feedback-id').textContent = `#${item.id}`;
    card.querySelector('.message').textContent = item.message;
    card.querySelector('.identity dd').textContent = item.name || '未留下称呼';
    card.querySelector('.contact dd').textContent = item.contact || '未留下联系方式';
    card.querySelector('.source').textContent = `来自 ${item.source}`;

    for (const button of card.querySelectorAll('.status-actions button')) {
      const isActive = button.dataset.next === item.status;
      button.classList.toggle('active', isActive);
      button.setAttribute('aria-pressed', String(isActive));
      button.addEventListener('click', () => updateFeedback(item.id, button.dataset.next, card));
    }
    feedbackList.append(card);
  }
};

const loadFeedback = async () => {
  inboxStatus.textContent = '正在读取反馈…';
  inboxStatus.className = 'inbox-status';
  refreshButton.disabled = true;

  try {
    const data = await request(`/api/admin/feedback?status=${activeStatus}`);
    for (const [status, count] of Object.entries(data.counts)) {
      const counter = document.querySelector(`#count-${status}`);
      if (counter) counter.textContent = count;
    }
    renderFeedback(data.items);
    inboxStatus.textContent = `${data.items.length} 条反馈`;
  } catch (error) {
    if (error.status === 401) return showLogin('登录已过期，请重新输入密码。');
    inboxStatus.textContent = error.message;
    inboxStatus.className = 'inbox-status error';
  } finally {
    refreshButton.disabled = false;
  }
};

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = loginForm.querySelector('button');
  const password = loginForm.elements.password.value;
  button.disabled = true;
  loginStatus.textContent = '正在验证…';

  try {
    await request('/api/admin/login', {
      method: 'POST',
      body: JSON.stringify({ password }),
    });
    loginForm.reset();
    showDashboard();
    await loadFeedback();
  } catch (error) {
    loginStatus.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

filters.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-status]');
  if (!button || button.dataset.status === activeStatus) return;
  activeStatus = button.dataset.status;
  filters.querySelectorAll('.filter').forEach((item) => item.classList.toggle('active', item === button));
  await loadFeedback();
});

refreshButton.addEventListener('click', loadFeedback);
logoutButton.addEventListener('click', async () => {
  await request('/api/admin/logout', { method: 'POST' });
  showLogin('你已经安全退出。');
});

(async () => {
  try {
    const session = await request('/api/admin/session');
    if (!session.configured) return showLogin('管理页尚未完成安全配置。');
    if (!session.authenticated) return showLogin();
    showDashboard();
    await loadFeedback();
  } catch (error) {
    showLogin(error.message);
  }
})();
