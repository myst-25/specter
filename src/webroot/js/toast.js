export function showToast(message, options = {}) {
  const { action, icon, type, autoCloseDelay = 3000, onActionClick, className } = options;

  const toast = document.createElement('div');
  toast.className = 'md-toast' + (className ? ' ' + className : '') + (type ? ' md-toast--' + type : '');
  toast.innerHTML = `
    ${icon ? `<md-icon class="md-toast__icon">${icon}</md-icon>` : ''}
    <span class="md-toast__message">${message}</span>
    <div class="md-toast__actions">
      ${action ? `<button class="md-toast__action">${action}</button>` : ''}
      <button class="md-toast__close" aria-label="Close"><md-icon>close</md-icon></button>
    </div>
  `;

  document.body.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('md-toast--open'));

  toast.querySelector('.md-toast__close').onclick = () => close(toast);

  if (action && onActionClick) {
    toast.querySelector('.md-toast__action').onclick = () => {
      close(toast);
      onActionClick();
    };
  }

  if (autoCloseDelay > 0) {
    const timer = setTimeout(() => close(toast), autoCloseDelay);
    toast._autoTimer = timer;
  }

  initSwipe(toast);

  return toast;
}

function initSwipe(toast) {
  let startX = 0;
  let currentX = 0;
  let dragging = false;

  const onStart = (e) => {
    startX = e.clientX;
    currentX = 0;
    dragging = true;
    toast.style.transition = 'none';
    if (toast._autoTimer) {
      clearTimeout(toast._autoTimer);
      toast._autoTimer = null;
    }
  };

  const onMove = (e) => {
    if (!dragging) return;
    currentX = e.clientX - startX;
    if (currentX < 0) currentX = 0;
    const maxDrag = window.innerWidth * 0.4;
    const clamped = Math.min(currentX, maxDrag);
    toast.style.transform = `translateX(calc(-50% + ${clamped}px)) translateY(0)`;
  };

  const onEnd = () => {
    if (!dragging) return;
    dragging = false;
    toast.style.transition = '';
    if (currentX > 80) {
      dismiss(toast);
    } else {
      toast.style.transform = '';
      toast.classList.add('md-toast--open');
    }
  };

  toast.addEventListener('pointerdown', onStart, { passive: true });
  toast.addEventListener('pointermove', onMove, { passive: true });
  toast.addEventListener('pointerup', onEnd);
  toast.addEventListener('pointercancel', onEnd);
}

function dismiss(toast) {
  toast.classList.remove('md-toast--open');
  toast.classList.add('md-toast--dismiss');
  toast.addEventListener('transitionend', () => {
    if (toast.parentNode) toast.parentNode.removeChild(toast);
  }, { once: true });
  setTimeout(() => {
    if (toast.parentNode) toast.parentNode.removeChild(toast);
  }, 300);
}

function close(toast) {
  toast.classList.remove('md-toast--open');
  toast.addEventListener('transitionend', () => {
    if (toast.parentNode) toast.parentNode.removeChild(toast);
  }, { once: true });
  setTimeout(() => {
    if (toast.parentNode) toast.parentNode.removeChild(toast);
  }, 300);
}
