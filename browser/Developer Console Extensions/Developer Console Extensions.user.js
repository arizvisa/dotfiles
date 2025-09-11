// ==UserScript==
// @name             Developer Console Extensions
// @description      This adds a number of utilities to the developer console object
// @version          1
// @allframes        true
// @match            *://*/*
// @run-at           document_end
// @inject-into      page
// @matchAboutBlank  true
// @grant            GM.info
//
// ==/UserScript==

/*
    Most of the logic/methodology used in this script was either inspired or ripped from the following sources:

    https://stackoverflow.com/questions/11849562/how-to-save-the-output-of-a-console-logobject-to-a-file
    https://stackoverflow.com/questions/2303147/injecting-js-functions-into-the-page-from-a-greasemonkey-script-on-chrome

*/

var DEFAULTS = {
  $DEBUG: false,
  window: (typeof unsafeWindow === "undefined")? window.wrappedJSObject : unsafeWindow,
};

/// create a global variable and update it with the DEFAULTS if it doesn't exist yet.
var GLOBAL;
  if (typeof GLOBAL === "undefined") { GLOBAL = {}; }
  for (let attribute in DEFAULTS) { GLOBAL[attribute] = DEFAULTS[attribute]; }
DEFAULTS = undefined;

/// because the author of FM is a fucking idiot...oh, and erosman/support#429.
if (typeof GM === "undefined") {
  GLOBAL.info = {
    scriptHandler: "FireMonkeyIsWrittenByAFuckingIdiot",
    script: {},
  };
} else {
  GLOBAL.info = GM.info;
}

if (typeof GLOBAL.info.script.uuid === "undefined") {
  GLOBAL.info.script.uuid = `GUID\$${window.crypto.randomUUID().replaceAll("-", "$")}`;
}

/// object for providing an identifier unique to the script rather than the running instance.
GLOBAL.private = ((info, private) => {
  const owner = info.scriptHandler;
  const uuid = info.script.uuid;

  let id = uuid.replace(/\W/g, '$');
  let name = `${owner}\$${id}`;

  let variable = (typeof private === "undefined")? 0 : private.count();
  return {
    id: () => uuid,
    owner: () => owner,
    name: () => name,
    count: () => variable,
    new: () => `\$${name}\$${variable++}`,
  };
})(GLOBAL.info, GLOBAL.private);

/** main code **/
function main(items) {

  /// aggregate an array of the necessary chunks for our closures
  let res = [];

  /// FireMonkey's editor, syntax highlighter, and even the damned linter are written by a fucking retard...
  for (let item of items) {
    // res = res.concat(inject_closure(((owner, name) => console.info(`${owner}: attempting to attach following closure to "console.${name}"...`)), GLOBAL.private.name(), item.name));
    res = res.concat(inject_closure(((owner, name) => console.info(owner + `: attempting to attach following closure to "` + ["console", name].join(".") + `"...`)), GLOBAL.private.name(), item.name));

    // res = res.concat(inject_scope(((owner, closure) => console.info(`${owner}: ${toSource(closure)}`)), {toSource: toSource}, GLOBAL.private.name(), item.closure));
    res = res.concat(inject_scope(((owner, closure) => console.info(owner + `: ` + toSource(closure))), {toSource: toSource}, GLOBAL.private.name(), item.closure));

    /// i fucking love how JS linters complain about the dumbest shit (potentially confusing semantics)...
    /// it is pretty damned obvious that JS programmers fucking suck at writing code if they get confused about scope.
    res = res.concat(setattr_console(item.name, item.closure));

    // res = res.concat(inject_closure(((owner, name) => console.info(`${owner}: successfully attached closure to "console.${name}".`)), GLOBAL.private.name(), item.name));
    res = res.concat(inject_closure(((owner, name) => console.info(owner + `: successfully attached closure to "` + ["console", name].join(".") + `".`)), GLOBAL.private.name(), item.name));
  }

  /// add some other attributes to the console object
  res = res.concat(setattr_console("state", {}));

  /// convert these chunks into solid text objects that we'll append
  let chunks = res.map(item => new Text(item));

  /// create a script object and append all of our text items
  const script = document.createElement('script', { type: "text/javascript" });
  script.dataset.creator = GLOBAL.private.owner();
  script.dataset.owner = GLOBAL.private.id();

  if (GLOBAL.$DEBUG) {
    console.info(`Created ${script.toString()} with creator "${script.dataset.creator}" owned by ${script.dataset.owner}`);

    for (let index = 0; index < chunks.length; index++) {
      console.debug(`Line #${index}: ${chunks[index].wholeText}`);
    }
  }

  chunks.forEach(chunk => script.appendChild(chunk));

  /// inject the closure to remove our script element when we're done
  const Fcleanup = (creator, owner) => document.querySelectorAll(`script[data-creator="${creator}"][data-owner="${owner}"]`).forEach(E => E.remove());

  let closures = inject_closure(Fcleanup, script.dataset.creator, script.dataset.owner);

  if (GLOBAL.$DEBUG) {
    console.info(`Created cleanup closure for ${script.toString()} with selector: ${script.nodeName}[data-creator="${script.dataset.creator}"][data-owner="${script.dataset.owner}"]`);

    for (let index = 0; index < closures.length; index++) {
      console.debug(`Line #${index}: ${closures[index]}`);
    }
  }

  closures.forEach(chunk => script.appendChild(new Text(chunk)));

  /// finally we can attach it to the document
  (document.body || document.head || document.documentElement).appendChild(script);
}

function setattr_console(attribute, closure) {
  const varname = GLOBAL.private.new();

  let setattribute = (attribute, value) => { window.console[attribute] = value; };

  let res = [];
  res.push(`${varname} = ${toSource(closure)};`);
  res.push(`(${setattribute.toString()})(${toSource(attribute)}, ${varname});`);
  res.push(`delete(${varname});`);
  return res;
}

function inject_closure(closure, ...parameters) {
  const varname = GLOBAL.private.new();

  let res = [];
  res.push(`${varname} = ${toSource(closure)};`);
  res.push(`${varname}.apply(${undefined}, ${toSource(parameters)});`);
  res.push(`delete(${varname});`);
  return res;
}

function inject_scope(closure, scope, ...parameters) {
  const varname = GLOBAL.private.new();

  let res = [];
  res.push(`{`);
    for (let name in scope) {
      res.push(`let ${name} = ${toSource(scope[name])};`);
    }
    res.push(`${varname} = ${toSource(closure)};`);
    res.push(`${varname}.apply(${undefined}, ${toSource(parameters)});`);
    res.push(`delete(${varname});`);
  res.push(`}`);
  return res;
}

/** functions to load into the document **/
var TestAttributeAssignment = () => {
  console.warn('Successfully assigned the defined attributes!');

  /// collect all of the attributes currently assigned to the console
  let res = [];
  for (let item in console) {
    res.push(item);
  }

  console.info(`The console object has the following ${res.length} attributes:`);
  console.debug(res.join(', '));
};

var DownloadJSONBlob = (object, filename) => {
  const DefaultTabSize = 4;
  const DefaultMimeType = "text/json";
  const DefaultFilename = "console.json";

  /// check parameters
  if (object === undefined) {
    console.error(`DownloadJSONBlob: refusing to encode undefined value (${object})`);
    return false;
  }

  if (!filename) {
    console.warn(`DownloadJSONBlob: using default filename ${DefaultFilename}`);
    filename = DefaultFilename;

  } else {
    console.info(`DownloadJSONBlob: using specified filename ${filename}`);
  }

  /// encode the object into a json blob
  var encoded = JSON.stringify(object, undefined, DefaultTabSize);
  const blob = new Blob([encoded], { type: DefaultMimeType });
  console.info(`DownloadJSONBlob: successfully encoded object into ${blob.size} bytes`);

  /// create a fake link that we can simulate a click with
  const anchor = document.createElement('a');

  anchor.dataset.url = URL.createObjectURL(blob);
  anchor.dataset.filename = filename;
  anchor.dataset.mimetype = blob.type;

  anchor.href = anchor.dataset.url;
  anchor.download = anchor.dataset.filename;

  // create the event representing the click, and dispatch it
  const ev = new MouseEvent('click', { bubbles: 0, button: 0 });
  anchor.dispatchEvent(ev);

  return true;
};

/// because apparently the Object.prototype.toSource method is fucking Firefox specific...
var toSource = (object) => {
  switch (typeof(object)) {

  case "undefined":
    return "undefined";

  case "string":
    return "\"" + object.replace(/\n/g, "\\n").replace(/\"/g, "\\\"") + "\"";

  case "object":
    if (object === null) {
      return "null";
    }
    var a = [];
    if (object instanceof Array) {
      for (var i in object) {
        a.push(toSource(object[i]));
      }
      return "[" + a.join(", ") + "]";
    }

    for (var key in object) {
      if (object.hasOwnProperty(key)) {
        a.push(key + ": " + toSource(object[key]));
      }
    }
    return "{" + a.join(", ") + "}";

  default:
    return object.toString();
  }
};

var jqueryVersion = (jQuery) => {
  return jQuery.fn.jquery;
};

// jQuery._data(document, "events")
var jqueryEventReporter = (jQuery, selector, root) => {
  var s = [];
  jQuery(selector || '*', root).addBack().each(function() {

    // the following line is the only change from wherever i ripped this.
    var e = jQuery._data(this, 'events');
    if(!e) return;
    s.push(this.tagName);
    if(this.id) s.push('#', this.id);
    if(this.className) s.push('.', this.className.replace(/ +/g, '.'));
    for(var p in e) {
      var r = e[p],
        h = r.length - r.delegateCount;
      if(h) {
        s.push('\n', h, ' ', p, ' handler', h > 1 ? 's' : '');
      }
      if(r.delegateCount) {
        for(var q = 0; q < r.length; q++) {
          if(r[q].selector) s.push('\n', p, ' -> ', r[q].selector);
        }
      }
    }
    s.push('\n\n');
  });
  return s.join('');
};

var desired_attributes = () => {
  let items = [];

  /// load a number of attributes that we want attached to the console
  items.push({name: "save", closure: DownloadJSONBlob});
  items.push({name: "export", closure: DownloadJSONBlob});
  items.push({name: "download", closure: DownloadJSONBlob});
  items.push({name: "toSource", closure: toSource});
  items.push({name: "jquery", closure: jqueryEventReporter});
  items.push({name: "jqueryVersion", closure: jqueryVersion});

  if (GLOBAL.$DEBUG) {
    items.push({name: "test", closure: TestAttributeAssignment});
  }

  return items;
};

/** actually perform our injection **/
main(desired_attributes());