let terminalEl = null;

export function initTerminal() {
  terminalEl = document.querySelector('.output-terminal-content');
  const clearBtn = document.getElementById('clear-terminal');
  if (clearBtn) {
    clearBtn.addEventListener('click', () => {
      if (terminalEl) terminalEl.innerHTML = '';
    });
  }
}

export function appendToOutput(content, error = false) {
  if (!terminalEl) return;
  if (content.trim() === '') {
    terminalEl.appendChild(document.createElement('br'));
  } else {
    const p = document.createElement('p');
    p.textContent = content;
    if (error) p.classList.add('output-line--error');
    terminalEl.appendChild(p);
  }
  terminalEl.scrollTop = terminalEl.scrollHeight;
}
