// Runs only after an explicit extension click or keyboard shortcut.
function capturePage() {
  const clean = (text, max = 2000) => String(text || '').replace(/\s+/g, ' ').trim().slice(0, max);
  const meta = (key) => document.querySelector(`meta[property="${key}"],meta[name="${key}"]`)?.content || '';
  const url = new URL(location.href);
  if (!['https:', 'http:'].includes(url.protocol)) throw new Error('Cette page ne peut pas être capturée.');
  const selection = clean(window.getSelection()?.toString());
  let result = { version: 1, id: crypto.randomUUID(), url: url.href, title: clean(meta('og:title') || document.title, 240), author: clean(meta('author'), 160), excerpt: selection, description: clean(meta('description') || meta('og:description'), 600), kind: 'page', seconds: null };
  const isYouTube = /(^|\.)youtube\.com$/.test(url.hostname) || url.hostname === 'youtu.be';
  if (isYouTube && (url.pathname === '/watch' || url.pathname.startsWith('/shorts/') || url.hostname === 'youtu.be')) {
    result.kind = 'video';
    const video = document.querySelector('video');
    if (video && Number.isFinite(video.currentTime) && video.readyState > 0) result.seconds = Math.floor(video.currentTime);
    result.author = clean(document.querySelector('#owner #channel-name a, ytd-channel-name a')?.textContent || result.author, 160);
    result.title = clean(document.querySelector('ytd-watch-metadata h1')?.textContent || result.title, 240);
  }
  if (['x.com', 'twitter.com', 'www.x.com', 'www.twitter.com'].includes(url.hostname)) {
    const match = url.pathname.match(/^\/([^/]+)\/status\/(\d+)/);
    // Only a permalink identifies a post unambiguously. Never collect a feed/thread in bulk.
    if (match) {
      result.kind = 'post';
      const path = `/${match[1]}/status/${match[2]}`;
      const post = Array.from(document.querySelectorAll('article[data-testid="tweet"]')).find(article => Array.from(article.querySelectorAll('a[href]')).some(a => a.getAttribute('href') === path && a.querySelector('time')));
      result.url = `${url.origin}${path}`;
      result.author = clean(post?.querySelector('[data-testid="User-Name"]')?.textContent || '@' + match[1], 160);
      result.excerpt = selection || clean(post?.querySelector('[data-testid="tweetText"]')?.textContent);
      if (result.excerpt) result.title = clean(result.excerpt, 160);
    }
  }
  // Keep the original URL, with a text fragment only when a selection exists.
  // Browsers may fail to resolve a fragment after a page has changed.
  if (selection && result.kind === 'page' && selection.length >= 12) {
    const base = url.href.split('#:~:text=')[0];
    result.url = base + (base.includes('#') ? ':~:text=' : '#:~:text=') + encodeURIComponent(selection.slice(0, 500)).replace(/-/g, '%2D');
  }
  return result;
}
if (typeof module !== 'undefined') module.exports = {capturePage};
