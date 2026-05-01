import { showToast } from './toast.js';

let lastStatus = null;

export function initNetwork() {
  updateNetworkStatus();
  setInterval(updateNetworkStatus, 3000);
  window.addEventListener('online', updateNetworkStatus);
  window.addEventListener('offline', updateNetworkStatus);
}

export async function updateNetworkStatus() {
  const online = await checkOnline();

  if (online === lastStatus) return;
  const wasOnline = lastStatus;
  lastStatus = online;

  const netChip     = document.getElementById('network-chip');

  const { getTranslation } = await import('./i18n.js');
  const onlineText  = getTranslation('home_status_online') || 'Online';
  const offlineText = getTranslation('home_status_offline') || 'Offline';

  if (online) {
    netChip?.classList.remove('offline');
    if (netChip) {
      const label = netChip.querySelector('#network-label');
      if (label) label.textContent = onlineText;
      const icon = netChip.querySelector('md-icon');
      if (icon) icon.textContent = 'wifi';
    }
  } else {
    netChip?.classList.add('offline');
    if (netChip) {
      const label = netChip.querySelector('#network-label');
      if (label) label.textContent = offlineText;
      const icon = netChip.querySelector('md-icon');
      if (icon) icon.textContent = 'wifi_off';
    }

    if (wasOnline === true) {
      showToast(offlineText);
    }
  }
}

const ONLINE_ENDPOINTS = [
  'https://clients3.google.com/generate_204',
  'https://www.gstatic.com/generate_204',
];

async function checkOnline() {
  if (!navigator.onLine) return false;
  for (const endpoint of ONLINE_ENDPOINTS) {
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 2000);
      await fetch(endpoint, { signal: ctrl.signal, mode: 'no-cors' });
      clearTimeout(timer);
      return true;
    } catch { /* try next endpoint */ }
  }
  return false;
}
