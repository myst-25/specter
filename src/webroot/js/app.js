import './material.js';
import { initBridge, spawnScript, getModuleDir as getBridgeModuleDir } from './bridge.js';
import { setModuleDir, migrateLocalStorage, cfgGet, cfgSet } from './cfg.js';
import { initDevice, refreshDevice, refreshKeyboxStatus } from './device.js';
import { initClock } from './clock.js';
import { initNetwork } from './network.js';
import { initTheme } from './theme.js';
import { initI18n } from './i18n.js';
import { loadContributors } from './contributors.js';
import { initRedirect } from './redirect.js';
import { escapeHtml } from './utils.js';
import { openRecentActivity, addEntry } from './history.js';
import { showToast } from './toast.js';
import { initTerminal, appendToOutput } from './terminal.js';

let devMode = false;
let friendlyNames = {};

document.addEventListener('DOMContentLoaded', async () => {
  try {
    await initBridge();
    setModuleDir(getBridgeModuleDir());
    await migrateLocalStorage();
  } catch (e) {
    console.warn('Bridge init failed, running without module path:', e);
  }

  wireTopBarScroll();
  const savedTheme = await cfgGet('theme', 'dark') || 'dark';
  initTheme(savedTheme);
  wireNavigation();
  wireActions();
  wireKeyboxCard();
  wireRefreshButton();
  await initI18n();
  initClock();
  initNetwork();
  await initDevice();
  loadContributors();
  initRedirect();
  buildFriendlyNames();

  const savedDevMode = await cfgGet('dev_mode', 'false') || 'false';
  devMode = savedDevMode === 'true';
  const sw = document.getElementById('dev-mode-switch');
  if (sw) sw.selected = devMode;
  wireDevMode();
  initTerminal();
});

function wireTopBarScroll() {
  const topBar = document.getElementById('top-bar');
  const main = document.querySelector('main');
  if (!topBar || !main) return;
  main.addEventListener('scroll', () => {
    topBar.classList.toggle('top-bar--scrolled', main.scrollTop > 0);
  });
}

function wireNavigation() {
  const navTabs = document.querySelectorAll('.nav-tab');
  const indicator = document.getElementById('nav-indicator');
  const pages = [
    document.getElementById('home-page'),
    document.getElementById('actions-page'),
    document.getElementById('advanced-page'),
    document.getElementById('settings-page'),
  ];

  function reposition(tab) {
    indicator.style.left = tab.offsetLeft + 'px';
    indicator.style.width = tab.offsetWidth + 'px';
  }

  requestAnimationFrame(() => {
    const active = document.querySelector('.nav-tab--active');
    if (active) reposition(active);
  });

  navTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      if (tab.classList.contains('nav-tab--active')) return;

      const oldTab = document.querySelector('.nav-tab--active');
      if (oldTab) {
        oldTab.classList.remove('nav-tab--active');
        oldTab.removeAttribute('aria-current');
        oldTab.querySelector('.nav-icon')?.classList.remove('nav-icon--filled');
      }

      tab.classList.add('nav-tab--active');
      tab.setAttribute('aria-current', 'page');
      tab.querySelector('.nav-icon')?.classList.add('nav-icon--filled');

      reposition(tab);

      const pageId = tab.dataset.page;
      pages.forEach((el) => {
        el.hidden = el.id !== pageId;
      });
      window.scrollTo({ top: 0, behavior: 'instant' });
    });
  });

  window.addEventListener('resize', () => {
    const active = document.querySelector('.nav-tab--active');
    if (active) reposition(active);
  });
}

function buildFriendlyNames() {
  document.querySelectorAll('.list-item[data-script]').forEach(item => {
    const scriptName = item.dataset.script;
    const headline = item.querySelector('.toggle-text[data-i18n]');
    if (headline) friendlyNames[scriptName] = headline.dataset.i18n;
  });
  window.__friendlyNames = friendlyNames;
}

function getFriendlyName(scriptName) {
  return friendlyNames[scriptName] || scriptName;
}

function wireDevMode() {
  const sw = document.getElementById('dev-mode-switch');
  if (!sw) return;
  sw.addEventListener('change', () => {
    devMode = sw.selected;
    cfgSet('dev_mode', sw.selected ? 'true' : 'false');
  });
}

function wireActions() {
  document.querySelectorAll('.list-item[data-script]').forEach(item => {
    item.addEventListener('click', async () => {
      if (item.disabled) return;

      const scriptName = item.dataset.script;
      const spinner = item.querySelector('.action-spinner');

      item.disabled = true;
      spinner?.classList.remove('hidden');

      try {
        if (devMode) {
          await runDevAction(scriptName, item, spinner);
        } else {
          await runSimpleAction(scriptName, item, spinner);
        }
      } catch (_e) {
        console.warn('Action error:', _e);
      } finally {
        item.disabled = false;
        spinner?.classList.add('hidden');
      }
    });
  });
}

async function runDevAction(scriptName, item, spinner) {
  const lines = [];
  const { getTranslation } = await import('./i18n.js');

  appendToOutput(`> ${scriptName}`);

  const dialog = document.createElement('md-dialog');
  dialog.innerHTML = `
    <div slot="headline">${scriptName}</div>
    <div slot="content"><div class="terminal"><pre id="live-output"></pre></div></div>
    <div slot="actions">
      <md-text-button class="dialog-close">${getTranslation('dialog_close') || 'Close'}</md-text-button>
    </div>
  `;
  document.body.appendChild(dialog);

  dialog.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('close', () => document.body.removeChild(dialog));
  dialog.show();

  const pre = dialog.querySelector('#live-output');

  const child = spawnScript(scriptName, 'feature');
  child.stdout.on('data', line => {
    appendToOutput(line);
    lines.push(line);
    if (pre) pre.textContent += line + '\n';
    if (pre?.parentElement) pre.parentElement.scrollTop = pre.parentElement.scrollHeight;
  });
  child.stderr.on('data', line => {
    appendToOutput(line, true);
    lines.push('[!] ' + line);
    if (pre) pre.textContent += '[!] ' + line + '\n';
    if (pre?.parentElement) pre.parentElement.scrollTop = pre.parentElement.scrollHeight;
  });
  child.on('exit', (code) => {
    appendToOutput(`> ${scriptName} exited (code: ${code})`);
    addEntry(scriptName, lines.join('\n'));
  });
  child.on('error', err => {
    const msg = err.message || 'Unknown error';
    appendToOutput(`> Error: ${msg}`, true);
    addEntry(scriptName, msg);
  });
}

async function runSimpleAction(scriptName, item, spinner) {
  const { getTranslation } = await import('./i18n.js');
  const i18nKey = getFriendlyName(scriptName);
  const friendlyName = getTranslation(i18nKey) || i18nKey;
  const lines = [];

  appendToOutput(`> ${friendlyName}`);

  const dialog = document.getElementById('progress-dialog');
  const label = document.getElementById('progress-label');
  const text = document.getElementById('progress-text');
  if (label) label.textContent = friendlyName;
  if (text) text.textContent = getTranslation('simple_dialog_wait') || 'This may take a moment';
  dialog.show();

  const child = spawnScript(scriptName, 'feature');
  child.stdout.on('data', line => {
    appendToOutput(line);
    lines.push(line);
  });
  child.stderr.on('data', line => {
    appendToOutput(line, true);
    lines.push('[!] ' + line);
  });

  child.on('exit', (code) => {
    appendToOutput(`> ${friendlyName} exited (code: ${code})`);
    addEntry(scriptName, lines.join('\n'));
    dialog.close();

    if (code !== 0) {
      const errorMsg = lines.find(l => l.includes('Error')) || lines[lines.length - 1] || friendlyName;
      showToast(`${getTranslation('simple_toast_error') || 'Failed'}: ${errorMsg}`, {
        icon: 'error',
        type: 'error',
        action: getTranslation('simple_toast_view_details') || 'View Details',
        autoCloseDelay: 8000,
        onActionClick: () => {
          const errDialog = document.createElement('md-dialog');
          errDialog.innerHTML = `
            <div slot="headline">${getTranslation('error_dialog_title') || 'Error Details'}</div>
            <div slot="content"><div class="terminal"><pre>${escapeHtml(lines.join('\n'))}</pre></div></div>
            <div slot="actions">
              <md-text-button class="dialog-close">${getTranslation('dialog_close') || 'Close'}</md-text-button>
            </div>
          `;
          document.body.appendChild(errDialog);
          errDialog.querySelector('.dialog-close').addEventListener('click', () => errDialog.close());
          errDialog.addEventListener('close', () => document.body.removeChild(errDialog));
          errDialog.show();
        },
      });
    } else {
      showToast(getTranslation('toast_success') || 'Done ✓', {
        icon: 'check_circle',
        type: 'success',
        autoCloseDelay: 3000,
      });
    }
  });

  child.on('error', err => {
    const msg = err.message || 'Unknown error';
    appendToOutput(`> Error: ${msg}`, true);
    addEntry(scriptName, msg);
    dialog.close();
    showToast(`${getTranslation('simple_toast_error') || 'Failed'}: ${friendlyName}`, {
      icon: 'error',
      type: 'error',
      action: getTranslation('simple_toast_view_details') || 'View Details',
      autoCloseDelay: 8000,
      onActionClick: () => {
        const errDialog = document.createElement('md-dialog');
        errDialog.innerHTML = `
          <div slot="headline">${getTranslation('error_dialog_title') || 'Error Details'}</div>
          <div slot="content"><div class="terminal"><pre>${escapeHtml(msg)}</pre></div></div>
          <div slot="actions">
            <md-text-button class="dialog-close">${getTranslation('dialog_close') || 'Close'}</md-text-button>
          </div>
        `;
        document.body.appendChild(errDialog);
        errDialog.querySelector('.dialog-close').addEventListener('click', () => errDialog.close());
        errDialog.addEventListener('close', () => document.body.removeChild(errDialog));
        errDialog.show();
      },
    });
  });
}

function wireRefreshButton() {
  const btn = document.getElementById('refresh-btn');
  if (!btn) return;
  btn.addEventListener('click', async () => {
    btn.disabled = true;
    await Promise.all([refreshDevice(), refreshKeyboxStatus()]);
    btn.disabled = false;
  });
}

function wireKeyboxCard() {
  const card = document.getElementById('keybox-card');
  if (!card) return;
  card.addEventListener('click', () => {
    const sw = document.getElementById('dev-mode-switch');
    openRecentActivity(sw ? sw.selected : false);
  });
}
