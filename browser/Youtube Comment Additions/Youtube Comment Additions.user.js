// ==UserScript==
// @name           Youtube Comment Additions
// @description    Add some extra features to a Youtube comment.
// @version        0.1
// @match          *://www.youtube.com/watch?*
// @include-test   *
// @connect        self
// @run-at         document-idle
// @grant          GM_xmlhttpRequest
//
// ==/UserScript==
"use strict";  // because JS is a fucking garbage language... firemonkey's editor is also pretty fucking stupid.

const comment_addition_tag = 'yt-comment-addition';
const youtube_client_version = '2.20240830.01.00';
const comment_addition_selection_class = `${comment_addition_tag}-selected`;

const comment_view_threads = 'ytd-comments ytd-comment-thread-renderer';
const comment_view_header = '#body > #main > #header';
const comment_view_styles = ['style-scope', 'ytd-comment-view-model'];
const comment_view_actionmenu_renderer = '#body > #action-menu > ytd-menu-renderer';
const comment_view_actionmenu_button = 'ytd-menu-renderer > yt-icon-button#button';
const comment_view_actionmenu_styles = ['style-scope', 'ytd-menu-renderer', 'dropdown-trigger'];
//ytd-comment-thread-renderer.style-scope:nth-child(62) > ytd-comment-view-model:nth-child(2) > div:nth-child(3) > div:nth-child(1) > a:nth-child(1)
const ytd_app_popupcontainer = 'ytd-popup-container.ytd-app';

function log(level, message) {
  let attribute = level.toLowerCase();
  console[attribute](`${comment_addition_tag}: ${message}`);
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
  //set_eq: (A, B) => A.size === B.size && A.union(B).size === A.size && A.intersection(B).size === A.size && A.difference(B).size === 0,
  set_eq: (A, B) => A.size === B.size && A.isSubsetOf(B),
  set_subsetQ: (A, B) => A.isSubsetOf(B),
  set_supersetQ: (A, B) => A.isSuperSetOf(B),
}

function Exception(message) {
  return {
    message: message,
    toString: () => `Exception: ${this.message}`,
  };
}

function assertHeaderSchematics(header) {
  const class_expected = new Set(comment_view_styles);
  if (!javascript_is_stupid.set_eq(class_expected, new Set(header.classList))) {
    throw Exception(`aborting due to unexpected class: ${header.className}`);
  }

  let depth0 = header.querySelectorAll('div#header > #header-author, #pinned-comment-badge');
  if (depth0.length !== 2) {
    throw Exception(`unexpected number of elements (${depth0.length}) in header`);
  }

  let depth1 = header.querySelectorAll('div#header > #header-author > #author-comment-badge, #sponsor-comment-badge, #published-time-text');
  if (depth1.length !== 3) {
    throw Exception(`unexpected number of author elements (${depth1.length}) in header`);
  }
  return true;
}

function verifyHeaderSchematics(header) {
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
  let filtered = Array.from(selected).filter((element) => verifyHeaderSchematics(element));
  return filtered;
}

function markCommentThread(renderer, selected)
{
  const style = comment_addition_selection_class;
  if (renderer.tagName !== 'YTD-COMMENT-THREAD-RENDERER') {
    throw Exception(`aborting due to unexpected element tag: ${renderer.tagName}`);
  }

  const class_expected = new Set(comment_view_styles);
  if (javascript_is_stupid.set_subsetQ(class_expected, new Set(renderer.classList))) {
    throw Exception(`aborting due to unexpected class: ${renderer.className}`);
  }

  let classes = Array.from(renderer.classList);
  let marked = !(javascript_is_stupid.set_eq(class_expected, new Set(classes))) && renderer.classList.contains(style);
  log('debug', `specified thread (${marked? 'marked' : 'unmarked'}) has the following classes applied to it: ${classes.join()}.`);

  if ((!marked) && (!selected)) {
    log('debug', 'no need to unmark the specified thread due to it not being selected.')

  } else if ((marked) && (selected)) {
    log('debug', 'no need to mark the specified thread due to it having already been selected.')
  }

  if ((!marked) && (selected)) {
    log('info', 'marking the specified thread as being selected.');
    renderer.classList.add(style);

  } else if ((marked) && (!selected)) {
    log('info', 'deselecting and removing the mark from the specified thread.');
    renderer.classList.remove(style);
  }

  return marked;
}

function enumerateMarkedComments(document) {
  const selection = document.querySelectorAll(`ytd-comment-thread-renderer.${comment_addition_selection_class}`);
  return Array.from(selection);
}

function assertActionMenuSchematics(renderer) {
  const class_expected = new Set(comment_view_styles);
  if (!javascript_is_stupid.set_eq(class_expected, new Set(renderer.classList))) {
    throw Exception(`aborting due to unexpected class: ${renderer.className}`);
  }

  let depth0 = renderer.querySelectorAll('ytd-menu-renderer > yt-icon-button#button > button#button, yt-interaction#interaction');
  if (depth0.length !== 2) {
    throw Exception(`unexpected number of elements (${depth0.length}) in header`);
  }
  return true;
}

function getProfileViewModel(header) {
  return header.querySelector('#body > #author-thumbnail > a.yt-simple-endpoint');
}

function getActionMenuButtonDisplay(body) {
  let container = body.querySelector('ytd-popup-container.ytd-app > tp-yt-iron-dropdown.ytd-popup-container');
  if (container !== null) {
    return container.style['display'];
  }
  throw Exception(`unable to locate popup container from document body: ${body}`);
}

function getActionMenuButton(body) {
  const class_expected = new Set(comment_view_actionmenu_styles);

  let selected = body.querySelector(comment_view_actionmenu_renderer);
  assertActionMenuSchematics(selected);

  let button = selected.querySelector(comment_view_actionmenu_button);
  if (!javascript_is_stupid.set_eq(class_expected, new Set(button.classList))) {
    throw Exception(`aborting due to unexpected class: ${button.className}`);
  }
  return button;
}

function getPopupContainerMenuRenderer(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  let renderer = popups[0].querySelector('ytd-popup-container > tp-yt-iron-dropdown > div#contentWrapper > ytd-menu-popup-renderer.ytd-popup-container');
  return renderer.querySelector('tp-yt-paper-listbox > ytd-menu-service-item-renderer')
}

function getPopupContainerProfileView(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  let displayed = popups[0].querySelector('ytd-popup-container > tp-yt-iron-dropdown > div#contentWrapper > ytd-multi-page-menu-renderer.ytd-popup-container').parentElement.parentElement;
  let renderer = popups[0].querySelector('ytd-popup-container > tp-yt-iron-dropdown > div#contentWrapper > ytd-multi-page-menu-renderer.ytd-popup-container');
  return renderer.querySelector('tp-yt-paper-listbox > ytd-menu-service-item-renderer')
}

function getPopupContainerReportDialogDisplay(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  let paper = popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container');
  if (paper === null)
    throw Exception(`unable to find paper dialog.`);
  return paper.style['display'];
}

function getPopupContainerReportDialog(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  return popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container div#content');
//  return popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container');
}

function getPopupContainerReportReasons(dialogContent) {
  let scrollable = dialogContent.querySelector('#scroller > #scrollable > div#content');
  let fieldset = scrollable.querySelector('div#content fieldset');
  //let reason = dialogContent.querySelector('yt-report-form-reason-select-page-view-model.ytWebReportFormReasonSelectPageViewModelHost');
  //let fieldset = reason.querySelector('yt-report-form-reason-select-page-view-model yt-radio-button-group-view-model > fieldset');
  let ray_ay_di_yo_oh_oh = Array.from(fieldset.querySelectorAll('fieldset .YtRadioButtonItemViewModelHost'));
  let keeps_playing_our_old_song_again = ray_ay_di_yo_oh_oh.map((reason) => reason.querySelectorAll('input, label'));
  let to_remind_me_of_times = keeps_playing_our_old_song_again.map((selected) => {
    if (selected.length != 2) {
      throw Exception(`unexpected number of results (${selected.length}) in reason choice`);
    }
    let indices = {true : 0, false: 1};
    let index = selected[0].tagName == "INPUT";
    let button = selected[indices[!!index]];
    let label = selected[indices[!index]];
    return {'input': button, 'label': label.textContent};
  })
  let i_guess_thats_what_insincerity_brings_me = {};
  to_remind_me_of_times.forEach((choice) => {
    i_guess_thats_what_insincerity_brings_me[choice['label']] = choice['input'];
  });
  return i_guess_thats_what_insincerity_brings_me;
}

function getPopupContainerReportButton(dialogContent) {
  return dialogContent.querySelector('div#bottom-bar button-view-model');
}

async function clickReportButton(dialogContent) {
  let button = getPopupContainerReportButton(dialogContent);
  button.click();
  button.firstChild.click();
}

function getPopupContainerReportCompletionDisplay(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  let paper = popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container > ytd-engagement-panel-section-list-renderer.ytd-popup-container').parentElement;
  if (paper === null)
    throw Exception(`unable to find paper dialog.`);
  return paper.style['display'];
}

function getPopupContainerReportCompletion(body) {
  let popups = body.querySelectorAll('ytd-popup-container.ytd-app');
  if (popups.length !== 1) {
    throw Exception(`unexpected number of elements (${popups.length}) in header`);
  }
  return popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container > ytd-engagement-panel-section-list-renderer.ytd-popup-container > div#content');
//  return popups[0].querySelector('ytd-popup-container > tp-yt-paper-dialog.ytd-popup-container > ytd-engagement-panel-section-list-renderer.ytd-popup-container');
}

function getPopupContainerReportCompletionButton(dialogContent) {
  return dialogContent.querySelector('div#bottom-bar button-view-model');
}

async function clickReportCompletionButton(dialogContent) {
  let button = getPopupContainerReportCompletionButton(dialogContent);
  button.click();
  button.firstChild.click();
}

function newElement(document, type, id) {
  const result = document.createElement(type);
  result.id = id;
  result.classList.add('style-scope');
  result.classList.add('ytd-comment-view-model');
  return result;
}

function insertRow(header, index, element) {
  assertHeaderSchematics(header);
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
  assertHeaderSchematics(header);
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
  assertHeaderSchematics(header);
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
  assertHeaderSchematics(header);
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

function headerSpam(event, header) {
  event.preventDefault();

  let document_body = header.ownerDocument.body;
  let comment_body = header.parentElement.parentElement;

  let observers = {};

  function clickActionMenuButton() {
    /* FIXME: this needs to check for the "Report" menu button.
    if (getActionMenuButtonDisplay(comment_body) !== 'none') {
      return;
    }
    */

    // observe action_menu
    observers.action_button = getActionMenuButton(comment_body);
    observers.action_button.click();
  }

  function clickMenuPopup() {
    /* FIXME: this needs to check the right menu.
    if (getPopupContainerReportDialogDisplay(document_body) !== 'none') {
      return;
    }
    */
    // observe report_dialog
    observers.action_menu = getPopupContainerMenuRenderer(document_body);
    observers.action_menu.click();
  }

  function grabReportDialog() {
    if (getPopupContainerReportDialogDisplay(document_body) === 'none') {
      throw Exception(`Unable to locate the report dialog.`);
    }
    observers.report_dialog = getPopupContainerReportDialog(document_body);
  }

  function selectDialogReportType(name) {
    if (getPopupContainerReportDialogDisplay(document_body) === 'none') {
      throw Exception(`Unable to select report type due to dialog not currently being visible.`);
    }

    let reasons = getPopupContainerReportReasons(observers.report_dialog);
    if (!(name in reasons)) {
      throw Exception(`Unable to find the specified reason (${name}) in list of report reasons (${keys(reasons).join()}).`);
    }
    reasons[name].click();
  }

  function clickReportDialogButton() {
    if (getPopupContainerReportDialogDisplay(document_body) === 'none') {
      throw Exception(`Unable to click report button due to dialog not currently being visible.`);
    }

    // FIXME: would be nice to figure out
    let button = getPopupContainerReportButton(observers.report_dialog);
    button.click();           // XXX: this is not the right button
    button.firstChild.click();
  }

  function grabCompletionDialog() {
    /* FIXME: this is busted
    if (getPopupContainerReportCompletionDisplay(document_body) === 'none') {
      throw Exception(`Unable to locate the report completion dialog.`);
    }
    */
    observers.report_completion = getPopupContainerReportCompletion(document_body);
  }

  function clickReportCompletionButton() {
    /* FIXME:
    if (getPopupContainerReportDialogDisplay(document_body) === 'none') {
      throw Exception(`Unable to click report button due to dialog not currently being visible.`);
    }
    */

    // FIXME: would be nice to figure out
    let button = getPopupContainerReportCompletionButton(observers.report_completion);
    button.click();           // XXX: this is not the right button
    button.firstChild.click();
  }

  // FIXME: we need to monitor events to figure out when the
  //        button is actually "clicked".
  let order = [
    clickActionMenuButton,
    clickMenuPopup,
    grabReportDialog,
    () => selectDialogReportType('Spam or misleading'),
    clickReportDialogButton,
    grabCompletionDialog,
    clickReportCompletionButton,
  ];

  function hack(index) {
    if (index < order.length) {
      let F = order[index];
      F();
      setTimeout(() => hack(1 + index), 100);
    }
  }
  setTimeout(() => hack(0), 100);

  // sure would be nice if we had a fucking mutex...but again...
  // javascript is a fake programming language written by idiots
  // who insist on making things more complex than they need to be.
}

function updateHeader(document, header) {
  const id = 'decoration';
  if (header.querySelector(`#${id}`)) {
    return;
  }

  let spam = newElement(document, 'a', id);
    spam.href = '#';
    spam.textContent = "|spam|";
    spam.addEventListener('click', (event) => {
      event.preventDefault();
      headerSpam(event, header)
    }, {capture: true, passive: false});
  appendButton(header, 4, spam);

  let mark = newElement(document, 'a', id);
    mark.href = '#';
    mark.textContent = "|mark|";
    mark.addEventListener('click', (event) => {
      event.preventDefault();
      markCommentThread(header.parentElement.parentElement.parentElement.parentElement, true);
    }, {capture: true, passive: false});
  appendButton(header, 4, mark);
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

//let thread = $$('ytd-comment-thread-renderer')[3];
//get observing() { return 'ytd-comment-thread-renderer.style-scope:nth-child(4)'; }
class element_monitor {
  get observing() { return '*'; }
  get attributes() { return null; }

  logger(level, message) {
    let attribute = level.toLowerCase();
    // FIXME: output some information that can be used to identify the element being monitored.
    console[attribute](message);
  }

  constructor(body) {
    this.document = body.ownerDocument;
    this.parent = body.parentElement;
    let results = this.parent.querySelectorAll(this.observing);
    if (results.length !== 1) {
      throw Exception(`Unable to find element representing by the configured selector: ${this.observing}`);
      // FIXME: if we couldn't find the selected element, then we should use
      //        the observer to find it whenever it gets created.
    }

    let [result] = results;

    let obs = new MutationObserver((mutationList, observer) => {
      mutationList.forEach(mutation => {
        this.logger('debug', `mutation type: ${mutation.type}`);
        let args = [];
        switch (mutation.type) {
          case 'attributes':
            args.splice(0, 0, ...((mutation) => {
              let [ns, n] = [mutation.attributeNamespace, mutation.attributeName];
              this.logger('debug', `Attribute mutation namespace: ${ns}`);
              this.logger('debug', `Attribute mutation name: ${n}`);

              let [changing, changed] = [mutation.oldValue, mutation.target.getAttributeNS(ns, n)];
              this.logger('debug', `Attribute mutation oldvalue: ${changing}`);
              this.logger('debug', `Attribute mutation newvalue: ${changed}`);

              return [mutation.target, (ns === null)? n : [ns, n].join(':'), [changing, changed]];
            })(mutation));
            break;

          case 'characterData':
            args.splice(0, 0, ...((mutation) => {
              let [changing, changed] = [mutation.oldValue, mutation.target.data];
              this.logger('debug', `Character data mutation oldvalue: ${changing}`);
              this.logger('debug', `Character data mutation newvalue: ${changed}`);
              return [mutation.target, [changing, changed]];
            })(mutation));
            break;

          case 'childList':
            args.splice(0, 0, ...((mutation) => {
              let [added, removed] = [mutation.addedNodes, mutation.removedNodes];
              this.logger('debug', `Elements added: ${added.length}`);
              this.logger('debug', `Elements removed: ${removed.length}`);
              return [mutation.target, [added, removed]];
            })(mutation));
            break;

          default:
            throw Exception(`Received an unsupported mutation type (${mutation.type}).`);
        }

        try {
          this.observe(mutation, args);
        } catch (E) {
          throw Exception(`Observation of element raised exception: ${E}.`);
        }
      });
    });

    this.element = result;
    this.observer = obs;

    // check whether the element has had any of its attributes changed.
    let options = {
      childList: true,
      attributeOldValue: true,
      characterDataOldValue: true,
    };
    options.attributes = options.subtree = true;
    if (Array.isArray(this.attributes)) {
      options.attributesFilter = this.attributes;
    }
    obs.observe(this.element, options);
  }

  destroy() {
    this.observer.disconnect();
  }

  select() {
    return this.parent.querySelector(this.observing);
  }

  observe(mutation, args) {
    let target, addedNodes, removedNodes, attribute, changes;
    let oldvalue, newvalue;

    [addedNodes, removedNodes] = [[], []];
    [oldvalue, newvalue] = [null, null];

    this.logger('warn', `what is this: ${mutation.type}`);
    if (mutation.type === 'attributes') {
      [target, attribute, changes] = args;
      [oldvalue, newvalue] = changes;
    } else if (mutation.type === 'characterData') {
      [target, changes] = args;
      [oldvalue, newvalue] = changes;
    } else if (mutation.type === 'childList') {
      [target, changes] = args;
      [addedNodes, removedNodes] = changes;
    } else {
      throw Exception(`Received an unsupported mutation type (${mutation.type}).`);
    }

    if (typeof(attribute) === 'string') {
      this.logger('info', `Attribute ${attribute}: ${oldvalue} -> ${newvalue}`);
    } else if (addedNodes.length || removedNodes.length) {
      this.logger('info', `Removed ${removedNodes.length} nodes.`);
      this.logger('info', `Added ${addedNodes.length} nodes.`);
    } else {
      this.logger('info', `Character data: ${oldvalue} -> ${newvalue}`);
    }
  }

  get visible() {
    let result = this.element;
    return this.element.style['display'] !== 'none';
  }

  signal(event) {
    throw Exception(`Not implemented..`);
  }
};

/*
function testMonitor(body)
  class tester extends element_monitor {
    get observing() {
      return 'ytd-popup-container.style-scope ytd-menu-popup-renderer.style-scope';
    }
    get attributes() {
      return ['style'];
    }
  }
  let sel = body.querySelector('ytd-popup-container.style-scope');

  return new tester(sel);
}
window.testMonitor = testMonitor(document.body);
*/

// $$('ytd-popup-container.style-scope ytd-menu-popup-renderer.style-scope')
// if (0) {
//   let n = document.createElement('a');
//   n.id = 'fucker';
//   n.href = '#';
//   n.innerText='fuck';
//   e = $('.language-name');
//
//   //class t extends element_monitor
//   t = class extends element_monitor {
//     get observing() { return '.language-name'; }
//   };
//
//   x = new t(e);
//   e.appendChild(n);
// }

function setupCommentThreadObserver(document) {
  //const thread_item_element = 'ytd-comment-thread-renderer';
  const thread_item_element = comment_view_threads.slice(1 + comment_view_threads.lastIndexOf(' '), comment_view_threads.length);

  let ob;
  try {
    ob = commentHeaderElementObserver(document);
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

function createStyleSheet(document, rules) {
  let style = document.head.appendChild(document.createElement('style'));
  let sheet = style.sheet;

  //for (let index = 0; index < rules.length; index++) {
  for (let rule of rules) {
    if (!Array.isArray(rule)) {
        throw Exception(`Received a non-array for the selectors to apply as a style.`);
    }

    let selector = rule[0];

    let properties = [];
    for (let pindex = 1; pindex < rule.length; pindex++) {
      if (!Array.isArray(rule[pindex])) {
        log('warn', `Invalid format received for selector #{1+sheet.rules.length} (${selector}) rule #${pindex}: ${rule[pindex]}`);
        throw Exception(`Received a non-array to apply as a style to selector #${1+sheet.rules.length}: ${selector}`);
      }

      let items = rule[pindex];
      let property = `${items[0]}: ${items[1]}${items[2]? ' !important' : ''}`;
      log('debug', `Appending property for ${selector} as rule #${1+sheet.rules.length}: ${property}`);
      properties.push(property);
    }

    let rendered = properties.join('\n');
    log('debug', `Applying ${properties.length} properties to ${selector} as rule #${1+sheet.cssRules.length}.`);
    properties.forEach((property, index) => log('debug', `[${1 + index}] ${selector} has property: ${property}`));
    sheet.insertRule(`${selector}{${rendered}}`, sheet.cssRules.length);
  }

  return style;
}

// x = createStyleSheet(document, [[".yt-comment-addition-selected", ['background-color', 'red']]])
// x = createStyleSheet(document, [[`.${comment_addition_selection_class}`, ['background-color', 'red']]])

async function main()
{
  log('info', 'Attaching stylesheet...');
  let sheet = createStyleSheet(document, [
    [`.${comment_addition_selection_class}`, ['background-color', 'red']],
  ]);

  log('info', 'Updating available comments...');
  updateCommentThreadHeaders(document);

  log('info', 'Setting up observer...');
  let observer = setupCommentThreadObserver(document);
  /*
  try {
    let ob = commentHeaderElementObserver(unsafeWindow.document);
    ob.observe(unsafeWindow.document.body, {attributes: true, childList: true, subtree: true, attributesFilter: ['ytd-comment-thread-renderer']});
  } catch (E) {
    alert(E);
  }
  */
  log('info', 'Successfully loaded.');
}

try {
  main();
} catch(E) {
  alert(`${comment_addition_tag}: Failure: ${E}`);
}

/////////////////////////////////////

async function queryNextResults(document) {
  let body = {
    "context": {
      "client": {"clientName": "WEB", "clientVersion": youtube_client_version},
      "user": {"lockedSafetyMode": false},
      "request": {"useSsl": true}
    },
    "continuation": "..."
  };

  await fetch("https://www.youtube.com/youtubei/v1/next?prettyPrint=false", {
    "credentials": "include",
    "headers": {
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.5",
        "Content-Type": "application/json",
        "X-Youtube-Bootstrap-Logged-In": "true",
        "X-Youtube-Client-Name": "1",
        "X-Youtube-Client-Version": youtube_client_version,
        "X-Goog-AuthUser": "0",
        "X-Origin": "https://www.youtube.com",
        "Sec-GPC": "1",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "same-origin",
        "Sec-Fetch-Site": "same-origin",
        "Priority": "u=4"
    },
    "referrer": "https://www.youtube.com/watch?v=xpAAL8d1hOQ",
    "body": body,
    "method": "POST",
    "mode": "cors"
  });
}

async function queryProfileCard(document, worldId, context) {
  let body = {
    "context":
      {"client":
         {"clientName":"WEB","clientVersion":youtube_client_version},
       "user":{"lockedSafetyMode":false},
       "request":{"useSsl":true}
      },
    "profileOwnerObfuscatedGaiaId":"...",
    "profileCardContext":"..."
  };

  body.profileOwnerObfuscatedGaiaId = worldId;
  body.profileCardContext = context;

  let query="";

  await fetch("https://www.youtube.com/youtubei/v1/account/get_profile_card?prettyPrint=false", {
    "credentials": "include",
    "headers": {
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.5",
        "Sec-GPC": "1",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "no-cors",
        "Sec-Fetch-Site": "same-origin",
        "Content-Type": "application/json",
        "X-Goog-Visitor-Id": "...%3D%3D",
        "X-Youtube-Bootstrap-Logged-In": "true",
        "X-Youtube-Client-Name": "1",
        "X-Youtube-Client-Version": youtube_client_version,
        "X-Goog-AuthUser": "0",
        "X-Origin": "https://www.youtube.com",
    },
    "referrer": document.url,
    "body": query,
    "method": "POST",
    "mode": "cors"
  });
}
