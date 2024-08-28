// ==UserScript==
// @name           Twitter Unshorten URL
// @description    ..because fuck twitter.com tampering with your URLs
// @version        0.1
// @match          *://twitter.com/*/status/*
// @match          *://x.com/*/status/*
// @include-test   *
// @connect        self
// @connect        t.co
// @run-at         document_start
// @grant          GM_xmlhttpRequest
// @grant          unsafeWindow
// ==/UserScript==
"use strict";  // because JS is a fucking garbage language...

var example = "https://t.co/oj3daqXAZH";
var example2 = "<a ... href=\"https://t.co/whatev\">";

const twitter_shorturl = "https://t.co/*";
const twitter_shorturl_tag = "x-short-url";

function request(url, properties={}) {
  return new Promise((resolve, reject) => {
    let callbacks = {};
    callbacks.onload = (response) => resolve(response);
    callbacks.onerror = callbacks.onabort = callbacks.ontimeout = (response) => reject(response);
		GM_xmlhttpRequest({
      url: url,
      ...properties, ...callbacks
    });
  });
}

function anchorElementObserver() {
  return new MutationObserver((mutationList, observer) => {
    mutationList.forEach(element => {
      const anchors = element.querySelectorAll(`a[href^="${twitter_shorturl}"]`);
      anchors.forEach((item) => {
        item.classList.add(twitter_shorturl_tag);
        console.log(`${twitter_shorturl_tag}: unshortening url: ${item.attribute.href}`);
        unshorten(item.attribute.href).then(url => {
          item.setAttribute('x-short-url', item.attribute.href);
          item.setAttribute('x-long-url', url);
          item.setAttribute('href', url);
        });
      });
    });
  });
}

async function unshorten(url) {
  let response = await request(url);
  let document = response.responseXML;
  let head_noscript_content = document.querySelector("noscript");

  if (!head_noscript_content) {
    throw {Error: "Unable to find \"noscript\" tag in returned content.", Content: document.outerHTML};
  }

  let meta = new DOMParser().parseFromString(head_noscript_content.innerHTML, "text/html");
  let content = meta.head.firstChild.attributes['content'].value;
  if (!content) {
    throw {Error: "Unable to find \"content\" attribute of \"meta\" tag", Content: meta.outerHTML};
  }

  let [s, attribute] = [content, ""];
  do {
    if (s.startsWith("URL=")) {
      attribute = s;
      break;
    }
    s = (s.indexOf(';') >= 0)? s.substring(1 + s.indexOf(';')) : "";
  } while(s);

  if (!attribute.startsWith("URL=")) {
    throw {Error: "Unable to find \"URL=\" key in \"content\" attribute of \"meta\" tag", Content: content};
  }

  let res = attribute.substring("URL=".length);
  if (res.substring(0, 1) === '"') {
    let trimmed = res.substring(1);
    return (trimmed.indexOf('"') >= 0)? trimmed.substring(1, trimmed.indexOf('"')) : trimmed;
  }
	return (res.indexOf(';') >= 0)? res.substring(1, res.indexOf(';')) : res;
}

async function main(url)
{
  alert(await unshorten(url));
  if (false) {
    let ob = anchorElementObserver();
    const body = unsafeWindow.document.body;
    ob.observe(body, {attributes: true, childList: true, subtree: true, attributesFilter: ['href']});
  }
}

try {
	main(example);
} catch(E) {
  alert(`${twitter_shorturl_tag}: Failure: ${E}`);
}