importScripts('capture.js');
let capturing = false;
async function capture(tab) {
  if (capturing) return;
  capturing = true;
  try {
    if (!tab?.id || !/^https?:\/\//.test(tab.url || '')) throw new Error('Ouvre une page web pour garder une référence.');
    await chrome.action.setBadgeText({text: '…'});
    const results = await chrome.scripting.executeScript({target: {tabId: tab.id}, func: capturePage});
    const payload = results[0]?.result;
    if (!payload) throw new Error('Cette page ne laisse pas lire son contexte.');
    const reply = await chrome.runtime.sendNativeMessage('tools.pulsar.reprise', payload);
    if (!reply?.ok) throw new Error(reply?.error || 'Reprise n’a pas confirmé la capture.');
    await chrome.action.setBadgeBackgroundColor({color: '#87AA91'});
    await chrome.action.setBadgeText({text: '✓'});
    await chrome.action.setTitle({title: 'Gardé au bord — Reprise'});
    setTimeout(() => chrome.action.setBadgeText({text: ''}), 2200);
  } catch (error) {
    await chrome.action.setBadgeBackgroundColor({color: '#C27645'});
    await chrome.action.setBadgeText({text: '!'});
    await chrome.action.setTitle({title: 'Reprise : ' + error.message});
    await chrome.storage.local.set({lastError: String(error.message)});
    await chrome.tabs.create({url: chrome.runtime.getURL('help.html')});
  } finally { capturing = false; }
}
chrome.action.onClicked.addListener(capture);
chrome.commands.onCommand.addListener(async command => {
  if (command === 'capture') {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    await capture(tab);
  }
});
