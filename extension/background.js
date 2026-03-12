// Terminatab — Background Service Worker
// Opens a side panel on web pages, or a full terminal tab otherwise.

chrome.action.onClicked.addListener(async (tab) => {
  const url = tab.url || '';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    chrome.sidePanel.open({ tabId: tab.id });
  } else {
    chrome.tabs.update(tab.id, { url: chrome.runtime.getURL('terminal.html') });
  }
});
