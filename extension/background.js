// Terminatab — Background Service Worker
// Handles context-aware icon click: side panel on regular pages, full tab on new tab pages.

const NEW_TAB_PATTERNS = [
  'chrome://newtab',
  'chrome://new-tab-page',
];

function isNewTabUrl(url) {
  return NEW_TAB_PATTERNS.some(pattern => url.startsWith(pattern));
}

// Do NOT use sidePanel.setPanelBehavior({ openPanelOnActionClick: true })
// — that would bypass our custom click handler.

chrome.action.onClicked.addListener(async (tab) => {
  const url = tab.url || '';

  if (isNewTabUrl(url)) {
    // Full-page terminal in the current tab
    chrome.tabs.update(tab.id, { url: chrome.runtime.getURL('terminal.html') });
  } else {
    // Side panel on regular pages
    chrome.sidePanel.open({ tabId: tab.id });
  }
});
