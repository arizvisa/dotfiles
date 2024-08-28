// ==UserScript==
// @name           Youtube Comment Additions
// @description    Add some extra features to a Youtube comment.
// @version        0.1
// @match          *://www.youtube.com/watch?*
// @include-test   *
// @connect        self
// @connect        t.co
// @run-at         document-idle
// @grant          GM_xmlhttpRequest
// @grant          unsafeWindow
// ==/UserScript==
"use strict";  // because JS is a fucking garbage language...

const comment_addition_tag = 'yt-comment-addition';

const comment_view_threads = 'ytd-comments ytd-comment-thread-renderer';
const comment_view_header = "#body > #main > #header";
const comment_view_styles = ['style-scope', 'ytd-comment-view-model'];

function log(message) {
  console.log(`${comment_addition_tag}: ${message}`);
}

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

const javascript_is_stupid = {
  set_eq: (A, B) => A.size === B.size && A.union(B).size === A.size && A.intersection(B).size === A.size && A.difference(B).size === 0,
}

function Exception(message) {
  return {
    message: message,
    toString: () => `Exception: ${this.message}`,
  };
}

function assertSchematics(header) {
  const class_expected = new Set(comment_view_styles);
  if (!javascript_is_stupid.set_eq(class_expected, new Set(header.classList))) {
    throw Exception(`aborting due to unexpected class: ${header.className}`);
  }

  let depth0 = header.querySelectorAll('div#header > #header-author, #pinned-comment-badge');
  if (depth0.length !== 2) {
    throw Exception(`unexpected number of elements (${depth0.size}) in header`);
  }

  let depth1 = header.querySelectorAll('div#header > #header-author > #author-comment-badge, #sponsor-comment-badge, #published-time-text');
  if (depth1.length !== 3) {
    throw Exception(`unexpected number of author elements (${depth1.size}) in header`);
  }
  return true;
}

function verifySchematics(header) {
  const class_expected = new Set(comment_view_styles);
  if (!javascript_is_stupid.set_eq(class_expected, new Set(header.classList))) {
    return false;
  }

  let depth0 = header.querySelectorAll('div#header > #header-author, #pinned-comment-badge');
  if (depth0.length !== 2) {
    return false;
  }

  let depth1 = header.querySelectorAll('div#header > #header-author > #author-comment-badge, #sponsor-comment-badge, #published-time-text');
  if (depth1.length !== 3) {
    return false;
  }
  return true;
}

function queryHeaders(body) {
  let selected = body.querySelectorAll(comment_view_header);
  let filtered = Array.from(selected).filter((element) => verifySchematics(element));
  return filtered;
}

function newElement(document, type, id) {
  const result = document.createElement(type);
  result.id = id;
  result.classList.add('style-scope');
  result.classList.add('ytd-comment-view-model');
  return result;
}

function insertRow(header, index, element) {
  assertSchematics(header);
  let nodes = Array.from(header.childNodes).filter((node) => node.nodeName !== "#text");
  if (!((index >= 0) && (index <= nodes.length))) {
    throw Exception(`Invalid index ${index} due to being out of bounds (${0}..${nodes.length})`);
  }
  if (index < nodes.length) {
    header.insertBefore(element, nodes[index]);
  } else {
    header.appendChild(element);
  }
}

function appendRow(header, index, element) {
  assertSchematics(header);
  let nodes = Array.from(header.childNodes).filter((node) => node.nodeName !== "#text");
  if (!((index >= 0) && (index <= nodes.length))) {
    throw Exception(`Invalid index ${index} due to being out of bounds (${0}..${nodes.length})`);
  }
  if (index < nodes.length - 1) {
  	header.insertBefore(element, nodes[index + 1]);
  } else {
    header.appendChild(element);
  }
}

function insertButton(header, index, element) {
  assertSchematics(header);
  let author = header.querySelector('div#header > div#header-author');
  let nodes = Array.from(author.childNodes).filter((node) => node.nodeName !== "#text");
  if (!((index >= 0) && (index <= nodes.length))) {
    throw Exception(`Invalid index ${index} due to being out of bounds (${0}..${nodes.length})`);
  }
  if (index < nodes.length) {
    author.insertBefore(element, nodes[index]);
  } else {
    author.appendChild(element);
  }
}

function appendButton(header, index, element) {
  assertSchematics(header);
  let author = header.querySelector('div#header > div#header-author');
  let nodes = Array.from(author.childNodes).filter((node) => node.nodeName !== "#text");
  if (!((index >= 0) && (index <= nodes.length))) {
    throw Exception(`Invalid index ${index} due to being out of bounds (${0}..${nodes.length})`);
  }
  if (index < nodes.length) {
    author.insertBefore(element, nodes[index]);
  } else {
    author.appendChild(element);
  }
}

function updateHeader(document, header) {
  const id = 'decoration';
  if (header.querySelector(`#${id}`)) {
    return;
  }

  let anchor = newElement(document, 'a', id);
  anchor.href = "javascript:alert('why')"
  anchor.textContent = "|alert|";
  anchor.onclick = (event) => alert('fixdis');
  appendButton(header, 4, anchor);
}

function commentHeaderElementObserver(document) {
  return new MutationObserver((mutationList, observer) => {
    mutationList.forEach(mutation => {
      let element = mutation.target;
      queryHeaders(element).forEach((header) => {
        updateHeader(document, header);
      });
    });
  });
}

/*
async function twitter_unshorten(url) {
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
*/

function setupCommentThreadObserver(document) {
  //const thread_item_element = 'ytd-comment-thread-renderer';
	const thread_item_element = comment_view_threads.slice(1 + comment_view_threads.lastIndexOf(' '), comment_view_threads.length);

  try {
  	let ob = commentHeaderElementObserver(document);
  	ob.observe(document.body, {attributes: true, childList: true, subtree: true, attributesFilter: [thread_item_element]});
  } catch (E) {
    alert(E);
  }
  return ob;
}

function updateCommentThreadHeaders(document) {
  let threads = Array.from(document.querySelectorAll(comment_view_threads));
  let headers = threads.flatMap((thread) => queryHeaders(thread));
  headers.forEach((header) => updateHeader(document, header));
}

async function main()
{
  let unsafeWindow = window.wrappedJSObject;

  log('Updating available comments...');
  updateCommentThreadHeaders(unsafeWindow.document);

  log('Setting up observer...');
  let observer = setupCommentThreadObserver(unsafeWindow.document);
  /*
  try {
    let ob = commentHeaderElementObserver(unsafeWindow.document);
    ob.observe(unsafeWindow.document.body, {attributes: true, childList: true, subtree: true, attributesFilter: ['ytd-comment-thread-renderer']});
  } catch (E) {
  	alert(E);
  }
  */
  log('Successfully loaded.');
}

try {
	main();
} catch(E) {
  alert(`${comment_addition_tag}: Failure: ${E}`);
}