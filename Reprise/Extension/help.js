chrome.storage.local.get('lastError').then(({lastError}) => { if(lastError) document.getElementById('error').textContent = lastError; });
