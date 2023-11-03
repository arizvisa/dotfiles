// ==UserScript==
// @name        YouTube Video Quality
// @description This forces the video quality for a YouTube video
// @version     1
// @noframes
// @match       https://www.youtube.com/*
// @run-at      document-idle
// @grant       none
// ==/UserScript==

const Quality = "480p";

// Click on the video settings button
let button = document.querySelector('.ytp-settings-button');
button.click();

// Look through the settings menu, and simulate a click on the Quality item
let settings = document.querySelector('.ytp-settings-menu');
let qsetting = Array.prototype.slice.call(settings.querySelectorAll('.ytp-menuitem')).filter(item => item.querySelector('.ytp-menuitem-label').textContent === "Quality")[0];
qsetting.click();

// Locate the quality menu, and grab the available video qualities
let qmenu = document.querySelector('.ytp-quality-menu');
let qualities = qmenu.querySelectorAll('.ytp-menuitem');

// List the qualities so that the user knows what's available for the current video
console.info('Discovered video qualities:');
qualities.forEach(item => console.log(item.querySelector('span').innerText));

// Find the matching quality and click it
let q = Array.prototype.slice.call(qualities).filter(item => item.querySelector('span').innerText === Quality);
if (q) {
  console.info(`Choosing quality (match ${Quality}): ${q[0].textContent}`);
  q[0].click();

} else {
  console.error(`Unable to locate the requested quality: ${Quality}`);
}