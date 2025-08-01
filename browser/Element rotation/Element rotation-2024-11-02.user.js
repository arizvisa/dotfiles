// ==UserScript==
// @name         Element rotation
// @version      2024-11-02
// @description  Add some items to the context menu for rotating a specific element
// @author       Ali Rizvi-Santiago <arizvisa@gmail.com>
// @match        http*://*/*
// @run-at       document-start
// @grant        GM_info
// @grant        GM_registerMenuCommand
// ==/UserScript==

(function() {
    'use strict';

    const GLOBAL = {
        id: GM_info.script.name,
        timeout: 5.0,
        highlight: {
            color: 'red',
            style: 'solid',
            width: '1px',
        },
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
        const element = getter();
        let [original, rotated] = rotateElement(element, adjustment, unit);
        logwith(element, `Rotated following element by ${adjustment} ${angle_description[unit]}s: ${original}${unit} -> ${rotated}${unit}`);
    };

    // highlight the bounding box of the selected element for just a few seconds or something...
    // FIXME: it would nice to trap the mousemove event for a few seconds to apply
    //        a border to whatever element is being hovered over. we also might be able
    //        to use a timer so that over some duration, the border fades using rgba().
    const ElementPicker = (getter) => (ev) => {
        const element = getter();
        const style = element.style;
        logwith(element, 'Highlighting the following element:');

        let [has, original] = ['border' in style, style['border']];
        switch (typeof(GLOBAL.highlight)) {
            case 'string':
                has = {'border': 'border' in style, 'opacity': 'opacity' in style};
                original = {'border': style['border'], 'opacity': style['opacity']};
                style['border'] = GLOBAL.highlight;
                break;

            case 'object':
                has = {
                    'border-style': 'border-style' in style,
                    'border-color': 'border-color' in style,
                    'border-width': 'border-width' in style,
                    'border-collapse': 'border-collapse' in style,
                    'opacity': 'opacity' in style,
                };
                original = {
                    'border-style': style['border-style'],
                    'border-color': style['border-color'],
                    'border-width': style['border-width'],
                    'border-collapse': style['border-collapse'],
                    'opacity': style['opacity'],
                }

                style['border-style'] = GLOBAL.highlight.style;
                style['border-color'] = GLOBAL.highlight.color;
                style['border-width'] = GLOBAL.highlight.width;
                style['border-collapse'] = 'separate';
                break;

            default:
                throw new Error(`Unsupported type (${typeof(GLOBAL.highlight)}) for border highlight.`);
        }

        const restoreStyleForElement = (el, has, style) => {
            logwith(element, 'Restoring style for the following element:');
            for (let property in has) {
                if (has[property]) {
                    el.style[property] = style[property];
                } else {
                    el.style.removeProperty(property);
                }
            }
        };

        setTimeout(restoreStyleForElement, 1000.0 * GLOBAL.timeout, element, has, original);
    };

    const ElementHide = (getter) => (ev) => {
        const element = getter();
        let is_div = (element.tagName.toUpperCase() == 'div')? true : false;
        logwith(element, `Zapping (${ is_div? "display:none" : "visibility:hidden"}) the following element:`);

        // if we're a div or block element, then avoid displaying the block.
        if (is_div) {
            element.style['display'] = 'none';

        // otherwise, we can just set its visibility to remove it.
        } else {
            element.style['visibility'] = 'hidden';
        }
    };

    const ElementRemove = (getter) => (ev) => {
        const element = getter();
        const parent = element.parentNode;

        logwith(parent, `Removing element of type ${element.tagName} from the following parent element:`);

        let removed = parent.removeChild(element);

        logwith(element, `Removed the following element from parent element of type ${parent.tagName}.`);

    };

    const currentElement = getElementFromContextMenuLazy();
    const menuitems = {
        pick: GM_registerMenuCommand("Show", ElementPicker(currentElement)),
        reset: GM_registerMenuCommand("Reset", ElementReset(currentElement, 'deg'), {autoClose: true}),
        zap: GM_registerMenuCommand("Zap (hide)", ElementHide(currentElement), {autoClose: true}),
        remove: GM_registerMenuCommand("Remove", ElementRemove(currentElement), {autoClose: true}),
        rotate_90: GM_registerMenuCommand("Rotate 90", ElementRotator(currentElement, 90, 'deg'), {autoClose: true}),
        rotate_270: GM_registerMenuCommand("Rotate -90", ElementRotator(currentElement, -90, 'deg'), {autoClose: true}),
        rotate_180: GM_registerMenuCommand("Rotate 180", ElementRotator(currentElement, 180, 'deg'), {autoClose: true}),
        rotate_45: GM_registerMenuCommand("Rotate 45", ElementRotator(currentElement, 45, 'deg'), {autoClose: true}),
        rotate_225: GM_registerMenuCommand("Rotate -45", ElementRotator(currentElement, -45, 'deg'), {autoClose: true}),
    };
})();