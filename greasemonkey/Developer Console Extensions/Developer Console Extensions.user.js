// ==UserScript==
// @name        Developer Console Extensions
// @description This adds a number of utilities to the developer console object
// @version     2
// @noframes
// @run-at      document_end
// @grant       GM.info
// @inject-at   page
// ==/UserScript==

/*
    Most of the logic/methodology used in this script was either inspired or ripped from the following sources:

    https://stackoverflow.com/questions/11849562/how-to-save-the-output-of-a-console-logobject-to-a-file
    https://stackoverflow.com/questions/2303147/injecting-js-functions-into-the-page-from-a-greasemonkey-script-on-chrome

*/

const $DEBUG = false;

/** because the author of FM is a fucking idiot...oh, and erosman/support#429. **/
const GLOBAL = {};
if (typeof GM === "undefined") {
  GLOBAL.info = {
    scriptHandler: "FireMonkeyIsWrittenByAFuckingIdiot",
    script: {
      uuid: `GUID\$${crypto.randomUUID().replaceAll("-", "$")}`,
    },
  };
} else {
  GLOBAL.info = GM.info;
}

/** configuration **/
const private = ((info) => {
  const owner = info.scriptHandler;
  const uuid = info.script.uuid;

  let id = uuid.replace(/\W/g, '$');
  let name = `${owner}\$${id}`;

  let variable = 0;
  return {
    id: () => uuid,
    owner: () => owner,
    name: () => name,
    new: () => `\$${name}\$${variable++}`,
  };
})(GLOBAL.info);

/** main code **/
function main() {
  let items = [];

  // load a number of attributes that we want attached to the console
  items.push({name: "save", closure: DownloadJSONBlob});
  items.push({name: "export", closure: DownloadJSONBlob});
  items.push({name: "download", closure: DownloadJSONBlob});
  items.push({name: "toSource", closure: toSource});

  if ($DEBUG) {
    items.push({name: "test", closure: TestAttributeAssignment});
  }

  // aggregate an array of the necessary chunks for our closures
  let res = [];

  for (let item of items) {
    res = res.concat(setattr_console(item.name, item.closure));
  }

  // add some other attributes to the console object
  res = res.concat(setattr_console("state", {}));

  // convert these chunks into solid text objects that we'll append
  let chunks = res.map(item => new Text(item));

  // create a script object and append all of our text items
  const script = document.createElement('script', { type: "text/javascript" });
  script.dataset.creator = private.owner();
  script.dataset.owner = private.id();

  if ($DEBUG) {
    console.info(`Created ${script.toString()} with creator "${script.dataset.creator}" owned by ${script.dataset.owner}`);

    for (let index = 0; index < chunks.length; index++) {
      console.debug(`Line #${index}: ${chunks[index].wholeText}`);
    }
  }

  chunks.forEach(chunk => script.appendChild(chunk));

  // inject the closure to remove our script element when we're done
  const Fcleanup = (creator, owner) => document.querySelectorAll(`script[data-creator="${creator}"][data-owner="${owner}"]`).forEach(E => E.remove());

  let closures = inject_closure(Fcleanup, script.dataset.creator, script.dataset.owner);

  if ($DEBUG) {
    console.info(`Injecting cleanup closure for ${script.toString()} with selector: ${script.nodeName}[data-creator="${script.dataset.creator}"][data-owner="${script.dataset.owner}"]`);

    for (let index = 0; index < closures.length; index++) {
      console.debug(`Line #${index}: ${closures[index]}`);
    }
  }

  closures.forEach(chunk => script.appendChild(new Text(chunk)));

  // finally we can attach it
  (document.body || document.head || document.documentElement).appendChild(script);
}

function setattr_console(attribute, closure) {
  const varname = private.new();

  let setattribute = (attribute, value) => { window.console[attribute] = value; };

  let res = [];
  res.push(`${varname} = ${toSource(closure)};`);
  res.push(`(${setattribute.toString()})(${toSource(attribute)}, ${varname});`);
  res.push(`delete(${varname});`);
  return res;
}

function inject_closure(closure, ...parameters) {
  const varname = private.new();

  let res = [];
  res.push(`${varname} = ${toSource(closure)};`);
  res.push(`${varname}.apply(${undefined}, ${toSource(parameters)});`);
  res.push(`delete(${varname});`);
  return res;
}

/** functions to load into the document **/
const TestAttributeAssignment = () => {
  console.warn('Successfully assigned the defined attributes!');

  // collect all of the attributes currently assigned to the console
  let res = [];
  for (let item in console) {
    res.push(item);
  }

  console.info(`The console object has the following ${res.length} attributes:`);
  console.debug(res.join(', '));
};

const DownloadJSONBlob = (object, filename) => {
  const DefaultTabSize = 4;
  const DefaultMimeType = "text/json";
  const DefaultFilename = "console.json";

  // check parameters
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

  // encode the object into a json blob
  var encoded = JSON.stringify(object, undefined, DefaultTabSize);
  const blob = new Blob([encoded], { type: DefaultMimeType });
  console.info(`DownloadJSONBlob: successfully encoded object into ${blob.size} bytes`);

  // create a fake link that we can simulate a click with
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

// because apparently the Object.prototype.toSource method is fucking Firefox specific...
const toSource = (object) => {
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

/** actually perform our injection **/
main();