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

feedbackMessage?.addEventListener('input', () => {
  feedbackCount.textContent = String(feedbackMessage.value.length);
});

feedbackForm?.addEventListener('submit', async (event) => {
  event.preventDefault();

  const submitButton = feedbackForm.querySelector('button[type="submit"]');
  const formData = new FormData(feedbackForm);
  const payload = Object.fromEntries(formData.entries());

  submitButton.disabled = true;
  feedbackStatus.className = 'feedback-status';
  feedbackStatus.textContent = '正在送达……';

  try {
    const response = await fetch('/api/feedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const result = await response.json().catch(() => ({}));

    if (!response.ok) throw new Error(result.message || '提交失败，请稍后再试。');

    feedbackForm.reset();
    feedbackCount.textContent = '0';
    feedbackStatus.className = 'feedback-status success';
    feedbackStatus.textContent = '收到了，谢谢你。这个建议已经送到 Voke。';
  } catch (error) {
    feedbackStatus.className = 'feedback-status error';
    feedbackStatus.textContent = error.message || '提交失败，请稍后再试。';
  } finally {
    submitButton.disabled = false;
  }
});
