// ==UserScript==
// @name         Element rotation
// @namespace    http://tampermonkey.net/
// @version      2024-11-02
// @description  Add some items to the context menu
// @author       arizvisa@gmail.com
// @match        *://*/*
// @run-at       document_end
// @grant        GM_info
// @grant        GM_registerMenuCommand
// ==/UserScript==

(function() {
    'use strict';

    const GLOBAL = {
        id: GM_info.script.name,
    };

    function Error(message) {
        return {owner: GLOBAL.id, message: message};
    }

    function warn(message) {
        console.warn(`${GLOBAL.id}: ${message}`);
    }

    function log(message) {
        console.info(`${GLOBAL.id}: ${message}`);
    }

    function warnwith(context, message) {
        warn(message);
        console.warn(context);
    }

    function logwith(context, message) {
        log(message);
        console.info(context);
    }

    function dumpMouseEvent(ev) {
        log(`Event: ${ev}`);
        log(`view: ${ev.view}`);
        log(`client: ${ev.clientX}, ${ev.clientY}`);
        log(`screen: ${ev.screenX}, ${ev.screenY}`);
        log(`page: ${ev.pageX}, ${ev.pageY}`);
        log(`default: ${ev.x}, ${ev.y}`);
    }

    function dumpEvent(ev) {
        log(`Event: ${ev}`);
        for (let attribute in ev) {
            log(`Event.${attribute}: ${ev[attribute]}`);
        }
    }

    const getElementsFromMouseEvent = (ev) => {
        let [cx, cy] = [ev.clientX, ev.clientY];
        return document.elementsFromPoint(cx, cy);
    };

    const getElementFromMouseEvent = (ev) => {
        let elements = getElementsFromMouseEvent(ev);
        if (!elements) {
            throw new Error(`Unable to fetch elements from viewport coordinate (${ev.clientX}, ${ev.clientY}) -> (${ev.pageX}, ${ev.pageY}).`);
        }
        return elements[0];
    };

    const convertAngle = (number, from, to) => {
        let gon;
        switch (from) {
            case 'grad':
                gon = number;
                break;
            case 'deg':
                return convertAngle(10. / 9. * number, 'grad', to);
            case 'rad':
                return convertAngle(200. / Math.PI * number, 'grad', to);
            case 'turn':
                return convertAngle(400.0 * number, 'grad', to);
            default:
                throw new Error(`Unsupported unit (${from}) for source angle.`);
        }

        switch (to) {
            case 'grad':
                return gon;
            case 'deg':
                return 9. / 10. * gon;
            case 'rad':
                return Math.PI / 200. * gon;
            case 'turn':
                return 1. / 400.0 * gon;
        }

        throw new Error(`Unsupported unit (${to}) for destination angle.`);
    };

    const angle_description = {
        grad: 'gradian',
        deg: 'degree',
        rad: 'radian',
        turn: 'turn',
    };

    const rotateElement = (element, adjustment, type='deg') => {
        const style = element.style;
        const current = !style['rotate']? `0${type}` : style['rotate'];

        let [magnitude_] = current.match(/^[0-9.]+/);
        let [source] = [current.substring(magnitude_.length)];
        if (!magnitude_) { warnwith(element, `Unable to parse rotation magnitude from "${current}" of the following element. Defaulting to "0deg".`); }

        let [unit, magnitude] = [source? source : type, magnitude_? parseFloat(magnitude_) : 0.0];
        let oangle = convertAngle(magnitude, source, unit);
        let nangle = convertAngle(oangle + adjustment, unit, source? source : type);

        style['rotate'] = `${nangle}${source}`;
        return [oangle, convertAngle(nangle, source? source : type, unit)];
    };

/*
    const ElementReset = (unit) => (ev) => {
        const element = getElementFromMouseEvent(ev);

        const current = element.style.removeProperty('rotate');
        if (!current) {
            log(`Reset rotation for element ${element} despite it not having been rotated.`);
            return;
        }
        let [magnitude_] = current.match(/^[0-9.]+/);
        let [source] = [current.substring(magnitude_.length)];
        let magnitude = magnitude_? parseFloat(magnitude_) : 0.0;
        log(`Reset rotation for element ${element} from ${convertAngle(magnitude, source, unit)}${unit}.`);
    };

    const ElementRotator = (adjustment, unit) => (ev) => {
        const el = getElementFromMouseEvent(ev);
        let [original, rotated] = rotateElement(el, adjustment, unit);
        log(`Rotated element ${el} by ${adjustment} ${angle_description[unit]}s: ${original}${unit} -> ${rotated}${unit}`);
    };
*/

    function Test(getter) {
        return (ev) => {
            dumpMouseEvent(ev);
            log(getter());
        };
    }

    /**
    ** The GM_registerMenuCommand API doesn't seem to pass a mouse event
    ** containing the X-Y coordinates of the mouse. So, we monitor the
    ** "contextmenu" event explicitly, and use it to get the target element.
    **/
    function getElementFromContextMenuLazy() {
        let element;
        document.addEventListener("contextmenu", (event) => {
            element = event.target;
        });
        return () => { return element; }
    }

    // FIXME: we should be preserving the original rotation
    //        so that we can actually restore it here.
    const ElementReset = (getter, unit) => (ev) => {
        const element = getter();
        const current = element.style.removeProperty('rotate');
        if (!current) {
            logwith(element, `Resetting rotation for following element despite it not having been rotated.`);
            return;
        }
        let [magnitude_] = current.match(/^[0-9.]+/);
        let [source] = [current.substring(magnitude_.length)];
        let magnitude = magnitude_? parseFloat(magnitude_) : 0.0;
        logwith(element, `Resetting rotation for following element from ${convertAngle(magnitude, source, unit)}${unit}.`);
    };

    const ElementRotator = (getter, adjustment, unit) => (ev) => {
        const el = getter();
        let [original, rotated] = rotateElement(el, adjustment, unit);
        logwith(el, `Rotated following element by ${adjustment} ${angle_description[unit]}s: ${original}${unit} -> ${rotated}${unit}`);
    };

    const currentElement = getElementFromContextMenuLazy();
    const menuitems = {
        //test: GM_registerMenuCommand("Check", Test(currentElement)),
        reset: GM_registerMenuCommand("Reset", ElementReset(currentElement, 'deg'), {autoClose: true}),
        rotate_90: GM_registerMenuCommand("Rotate 90", ElementRotator(currentElement, 90, 'deg'), {autoClose: true}),
        rotate_180: GM_registerMenuCommand("Rotate 180", ElementRotator(currentElement, 180, 'deg'), {autoClose: true}),
        rotate_270: GM_registerMenuCommand("Rotate -90", ElementRotator(currentElement, -90, 'deg'), {autoClose: true}),
    };
})();