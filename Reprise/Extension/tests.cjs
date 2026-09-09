const assert = require('node:assert/strict');
const {capturePage} = require('./capture.js');
global.crypto = require('node:crypto').webcrypto;
function page(url, {title='Titre de la page', selection='', metadata={}, nodes={}, articles=[]}={}) {
  global.location = {href:url};
  global.window = {getSelection:()=>({toString:()=>selection})};
  global.document = {title, querySelector:(selector)=>{
    const match=selector.match(/meta\[property="([^"]+)"\]/);
    return match ? (metadata[match[1]] ? {content:metadata[match[1]]}:null) : nodes[selector] || null;
  }, querySelectorAll:()=>articles};
}
page('https://example.com/article',{metadata:{'og:title':'Le bon titre',author:'Auteur'},selection:'Un passage précis à retrouver.'});
let result=capturePage();
assert.equal(result.title,'Le bon titre');assert.equal(result.author,'Auteur');assert.equal(result.excerpt,'Un passage précis à retrouver.');assert.match(result.url,/#:~:text=/);
page('https://www.youtube.com/watch?v=abc',{nodes:{video:{currentTime:763.4,readyState:4},'ytd-watch-metadata h1':{textContent:'Le tutoriel'},'#owner #channel-name a, ytd-channel-name a':{textContent:'La chaîne'}}});
result=capturePage();assert.equal(result.seconds,763);assert.equal(result.kind,'video');assert.equal(result.title,'Le tutoriel');
page('https://www.youtube.com/watch?v=abc');assert.equal(capturePage().seconds,null);
const post={querySelectorAll:()=>[{getAttribute:()=>'/person/status/123',querySelector:()=>({})}],querySelector:s=>({textContent:s.includes('User-Name')?'Person @person':'Un post intéressant'})};
page('https://x.com/person/status/123?s=20',{articles:[post]});result=capturePage();assert.equal(result.excerpt,'Un post intéressant');assert.equal(result.url,'https://x.com/person/status/123');
page('https://x.com/home',{articles:[post]});assert.equal(capturePage().kind,'page');assert.equal(capturePage().excerpt,'');
page('https://example.com/');assert.equal(capturePage().title,'Titre de la page');
page('chrome://extensions/');assert.throws(capturePage);
console.log('PASS: article metadata/selection, YouTube timestamp/no-player fallback, exact X post, feed fallback, restricted page');
