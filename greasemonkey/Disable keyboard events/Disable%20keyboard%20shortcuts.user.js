// ==UserScript==
// @name           Disable keyboard events
// @description    Stop websites from hijacking the fucking keyboard
//
// @run-at         document-start
// @include        *
// @grant          none
// ==/UserScript==

(function () {
  "use strict";
  var debug = 0;

  var eventHandlers = {
    keydown: function(ev) {
      if (debug) { console.info("down " + ev.keyCode); }
      ev.cancelBubble = true;
      ev.stopPropagation();
      ev.stopImmediatePropagation();
      return false;
    },
    keyup: function(ev) {
      if (debug) { console.info("up " + ev.keyCode); }
      ev.cancelBubble = true;
      ev.stopPropagation();
      ev.stopImmediatePropagation();
      return false;
    },
    keypress: function(ev) {
      if (debug) { console.info("press " + ev.keyCode); }
      ev.cancelBubble = true;
      ev.stopPropagation();
      ev.stopImmediatePropagation();
      return false;
    },
  };
  function main() {
    console.log("disable-keyboard-events> injecting event handler for keydown event...");
    document.addEventListener('keydown', eventHandlers.keydown);
    console.log("disable-keyboard-events> injecting event handler for keyup event...");
    document.addEventListener('keyup', eventHandlers.keyup);
    console.log("disable-keyboard-events> injecting event handler for keypress event...");
    document.addEventListener('keypress', eventHandlers.keypress);
    console.info("disable-keyboard-events> keyboard event handlers have been hooked!");
  }
  main();
}());