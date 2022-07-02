// GLOBALIZATION NOTE: Save this file using UTF-8 Encoding.

import System;
import System.Windows.Forms;
import Fiddler;

// JScript.NET Reference
// https://docs.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2010/z688wt03(v=vs.100)
//
// FiddlerScript Reference
// http://fiddler2.com/r/?fiddlerscriptcookbook

/** general configuration **/
class User
{
    static class Config {
        static var WorkingPath: String = "";
    }

    /*
    static function NewWorkspace() {
        User.Config.WorkingPath = User.Config.WorkingPath? User.Config.WorkingPath : Utils.Path.ChooseDirectory();
    }
    */

    static function Action(oSession: Session) {
        throw Exception.NotImplementedError;
    }
}

/** general exception types **/
class Exception
{
    static var NotImplementedError: Error = new Error(0, "NotImplementedError");
    static var SystemError: Error = new Error(0, "SystemError");
    static var RuntimeError: Error = new Error(0, "RuntimeError");
    static var FileNotFoundError: Error = new Error(0, "FileNotFoundError");
    static var FileExistsError: Error = new Error(0, "FileExistsError");
    static var NotADirectoryError: Error = new Error(0, "NotADirectoryError");
}

/** general utilities because jscript is retarded **/
class Utils
{
    static class String
    {
        static function Replace(string: String, substring: String, newstring: String): String {
            var items: String[] = string.Split([substring]);
            if (!items.Length)
                return string;
            var result: String = items[0];
            for (var index: int = 1; index < items.Length; index++) {
                result += newstring;
                result += items[index];
            }
            return result;
        }
        static function Join(separator: String, items: String[]): String {
            var result: String = items[0];
            for (var index: int = 1; index < items.Length; index++) {
                result += separator;
                result += items[index];
            }
            return result;
        }
    }

    /** utilities for interacting with both posix and windows paths **/
    static class Path
    {
        // Return whether a file or a directory exists
        static function FileExists(sPath: String): Boolean {
            return System.IO.File.Exists(Utils.Path.Windows(sPath));
        }
        static function DirectoryExists(sPath: String): Boolean {
            var path: String = sPath? sPath : User.Config.WorkingPath;
            return System.IO.Directory.Exists(Utils.Path.Windows(path));
        }

        // Convert a path to either its general (posix) form or its windows form
        static function Posix(sPath: String): String {
            return Utils.String.Replace(sPath, "\\", "/");
        }
        static function Windows(sPath: String): String {
            return Utils.String.Replace(sPath, "/", "\\");
        }

        static function ChooseFile(): String {
            var workingDirectory: String = Utils.Path.Windows(User.Config.WorkingPath);
            var filter: String = "All Files (*.*)|*.*";
            return Fiddler.Utilities.ObtainOpenFilename("Choose a file", filter, workingDirectory);
        }
        static function ChooseFiles(): String[] {
            var workingDirectory: String = Utils.Path.Windows(User.Config.WorkingPath);
            var filter: String = "All Files (*.*)|*.*";
            return Fiddler.Utilities.ObtainFilenames("Choose some files", filter, workingDirectory, true);
        }
        static function ChooseDirectory(): String {
            var dlg = new System.Windows.Forms.FolderBrowserDialog();
            dlg.Description = "Choose a directory";
            dlg.SelectedPath = Utils.Path.Windows(User.Config.WorkingPath);
            dlg.RootFolder = System.Environment.SpecialFolder.Desktop;
            var result = dlg.ShowDialog();
            return (result == System.Windows.Forms.DialogResult.OK)? Utils.Path.Posix(dlg.SelectedPath) : "";
        }
    }

    /** utilities for interacting with an individual session **/
    static class Session
    {
        // Return the default filename for a session
        static function Name(oSession: Fiddler.Session, sExtension: String): String {
            var suffix: String = sExtension? "." + sExtension : "";
            return suffix? oSession.id + "_" + suffix : oSession.SuggestedFilename;
        }
        // Return the path to a file in the working directory
        static function Path(oSession: Fiddler.Session, sExtension: String): String {
            var filename: String = Utils.Session.Name(oSession, sExtension);
            if (!Utils.Path.DirectoryExists(User.Config.WorkingPath))
                throw Exception.NotADirectoryError;
            return Utils.Path.Posix(User.Config.WorkingPath + "/" + filename);
        }
        // Return if the file for a session exists (in the working directory)
        static function Exists(oSession: Fiddler.Session, sExtension: String): Boolean {
            var path: String = Utils.Session.Path(oSession, sExtension);
            return System.IO.File.Exists(Utils.Path.Windows(path));
        }

        // Shortcuts for interacting with selections in the current workspace
        static function Everything(): Fiddler.Session[] {
            return FiddlerApplication.UI.GetAllSessions();
        }
        static function Selected(): Fiddler.Session[] {
            return FiddlerApplication.UI.GetSelectedSessions();
        }

        /** interacting with a session response **/
        static class Response
        {
            static class Headers
            {
                static function Get(oSession: Fiddler.Session): String {
                    return oSession.ResponseHeaders.ToString();
                }
                static function Set(oSession: Fiddler.Session, sHeaders: String): Boolean {
                    return oSession.ResponseHeaders.AssignFromString(sHeaders);
                }
            }

            // Replace the body of a session with the contents of a file
            static function Replace(oSession: Fiddler.Session, sExtension: String): byte[] {
                if (!Utils.Session.Exists(oSession, sExtension))
                    throw Exception.FileNotFoundError;

                var path: String = Utils.Session.Path(oSession, sExtension);
                var headers: String = Headers.Get(oSession);
                var result: byte[] = oSession.ResponseBody.Clone();

                FiddlerObject.log("Replacing response body of " + oSession.id + ": " + path);
                if (!oSession.LoadResponseFromFile(Utils.Path.Windows(path)))
                    FiddlerObject.log("Failure trying to load response body" + "(" + path + ")" + " into session " + oSession.id);

                // always ensure that the headers are restored when modifying the body
                Headers.Set(oSession, headers);
                return result;
            }
        }
    }
}

/** Preferences and settings for Fiddler **/
class Handlers
{
    /* preferences for simple breakpointing & other quickexec rules */
    BindPref("fiddlerscript.ephemeral.bpRequestURI") public static var bpRequestURI:String = null;
    BindPref("fiddlerscript.ephemeral.bpResponseURI") public static var bpResponseURI:String = null;
    BindPref("fiddlerscript.ephemeral.bpMethod") public static var bpMethod: String = null;

    // set certificate CN= using the request SNI
    BindPref("fiddler.network.https.SetCNFromSNI") public static var setCNFromSNI: boolean = true;

    // kerberos (SPN)
    //  0 – Disable setting of SPN
    //  1 – Use hostname from the URL as the SPN target
    //  2 – Use the target server’s canonical name as the SPN target, if the hostname is dotless; otherwise use the hostname from the URL
    //  3 – (Default) Use the target server’s canonical name as the SPN target
    BindPref("fiddler.auth.SPNMode") public static var spnMode: int = 0;
    BindPref("fiddler.auth.SPNIncludesPort") public static var spnIncludesPort: boolean = false;

    /** Main **/
    static function Main() {
        var today: Date = new Date();
        FiddlerObject.StatusText = "Session is starting at: " + today;

        if (!User.Config.WorkingPath)
            FiddlerObject.log("No workspace directory has been set!");
        else if (!Utils.Path.DirectoryExists(User.Config.WorkingPath))
            FiddlerObject.log("Working directory (" + Utils.Path.Posix(User.Config.WorkingPath) + ") does not exist!");
        else
            FiddlerObject.log("Using workspace: " + Utils.Path.Posix(User.Config.WorkingPath));

        FiddlerObject.log("To transparently proxy for a specific host: !listen $port $hostname");
        FiddlerObject.log("QuickExec help can be found at https://docs.telerik.com/fiddler/knowledge-base/quickexec");

        UI.lvSessions.AddBoundColumn("Server", 50, "@response.server");

        /* example of setting some hotkeys */
        // UI.RegisterCustomHotkey(HotkeyModifiers.Windows, Keys.G, "screenshot");

        /* end of configuration */
        var bar: String = "";
        for (var i = 0; i < 80; i++)
            bar += "=";
        FiddlerObject.log(bar);
    }

    /** Rules menu **/
        public static RulesOption("Request &Japanese Content")
        var m_Japanese: boolean = false;

        public static RulesOption("Hide 304s")
        BindPref("fiddlerscript.rules.Hide304s")
        var m_Hide304s: boolean = false;

        public static RulesOption("&Automatically Authenticate")
        BindPref("fiddlerscript.rules.AutoAuth")
        var m_AutoAuth: boolean = false;

    /** Rules Menu -> User-Agents **/
    // The page http://browserscope2.org/browse?category=selectors&ua=Mobile%20Safari is a good place to find updated versions of these
    RulesString("&User-Agents", true)
        BindPref("fiddlerscript.ephemeral.UserAgentString")
        RulesStringValue(0,"Netscape &3", "Mozilla/3.0 (Win95; I)")
        RulesStringValue(1,"WinPhone8.1", "Mozilla/5.0 (Mobile; Windows Phone 8.1; Android 4.0; ARM; Trident/7.0; Touch; rv:11.0; IEMobile/11.0; NOKIA; Lumia 520) like iPhone OS 7_0_3 Mac OS X AppleWebKit/537 (KHTML, like Gecko) Mobile Safari/537")
        RulesStringValue(2,"&Safari5 (Win7)", "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.21.1 (KHTML, like Gecko) Version/5.0.5 Safari/533.21.1")
        RulesStringValue(3,"Safari9 (Mac)", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11) AppleWebKit/601.1.56 (KHTML, like Gecko) Version/9.0 Safari/601.1.56")
        RulesStringValue(4,"iPad", "Mozilla/5.0 (iPad; CPU OS 8_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12F5027d Safari/600.1.4")
        RulesStringValue(5,"iPhone6", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12F70 Safari/600.1.4")
        RulesStringValue(6,"IE &6 (XPSP2)", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)")
        RulesStringValue(7,"IE &7 (Vista)", "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; SLCC1)")
        RulesStringValue(8,"IE 8 (Win2k3 x64)", "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.2; WOW64; Trident/4.0)")
        RulesStringValue(9,"IE &8 (Win7)", "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)")
        RulesStringValue(10,"IE 9 (Win7)", "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)")
        RulesStringValue(11,"IE 10 (Win8)", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)")
        RulesStringValue(12,"IE 11 (Surface2)", "Mozilla/5.0 (Windows NT 6.3; ARM; Trident/7.0; Touch; rv:11.0) like Gecko")
        RulesStringValue(13,"IE 11 (Win8.1)", "Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; rv:11.0) like Gecko")
        RulesStringValue(14,"Edge (Win10)", "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.11082")
        RulesStringValue(15,"&Opera", "Opera/9.80 (Windows NT 6.2; WOW64) Presto/2.12.388 Version/12.17")
        RulesStringValue(16,"&Firefox 3.6", "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.7) Gecko/20100625 Firefox/3.6.7")
        RulesStringValue(17,"&Firefox 43", "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:43.0) Gecko/20100101 Firefox/43.0")
        RulesStringValue(18,"&Firefox Phone", "Mozilla/5.0 (Mobile; rv:18.0) Gecko/18.0 Firefox/18.0")
        RulesStringValue(19,"&Firefox (Mac)", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:24.0) Gecko/20100101 Firefox/24.0")
        RulesStringValue(20,"Chrome (Win)", "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.48 Safari/537.36")
        RulesStringValue(21,"Chrome (Android)", "Mozilla/5.0 (Linux; Android 5.1.1; Nexus 5 Build/LMY48B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.78 Mobile Safari/537.36")
        RulesStringValue(22,"ChromeBook", "Mozilla/5.0 (X11; CrOS x86_64 6680.52.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.74 Safari/537.36")
        RulesStringValue(23,"GoogleBot Crawler", "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
        RulesStringValue(24,"Kindle Fire (Silk)", "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; en-us; Silk/1.0.22.79_10013310) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16 Silk-Accelerated=true")
        RulesStringValue(25,"&Custom...", "%CUSTOM%")
        public static var sUA: String = null;

    /** Rules Menu -> Peformance **/
        public static RulesOption("Simulate &Modem Speeds", "Per&formance") var m_SimulateModem: boolean = false;
        public static RulesOption("&Disable Caching", "Per&formance") var m_DisableCaching: boolean = false;
        public static RulesOption("Cache Always &Fresh", "Per&formance") var m_AlwaysFresh: boolean = false;

    /** Tools Menu **/
        public static ToolsAction("Reset Script")
        function DoManualReload() {
            FiddlerObject.ReloadScript();
        }

    /** Context Menu **/
        public static ContextAction("Decode Selected Sessions")
        function DoRemoveEncoding(oSessions: Session[]) {
            for (var x:int = 0; x < oSessions.Length; x++){
                oSessions[x].utilDecodeRequest();
                oSessions[x].utilDecodeResponse();
            }
            UI.actUpdateInspector(true,true);
        }

        public static ContextAction("Custom User Action")
        function CustomContextAction(oSessions: Session[]) {
            for (var index:int = 0; index < oSessions.Length; index++)
                User.Action(oSessions[index]);
            return;
        }

    /** Events **/
    static function OnBeforeRequest(oSession: Session) {
        // Sample Rule: Color ASPX requests in RED
        // if (oSession.uriContains(".aspx")) {	oSession["ui-color"] = "red";	}

        // Sample Rule: Flag POSTs to fiddler2.com in italics
        // if (oSession.HostnameIs("www.fiddler2.com") && oSession.HTTPMethodIs("POST")) {	oSession["ui-italic"] = "yup";	}

        // Sample Rule: Break requests for URLs containing "/sandbox/"
        // if (oSession.uriContains("/sandbox/")) {
        //     oSession.oFlags["x-breakrequest"] = "yup";	// Existence of the x-breakrequest flag creates a breakpoint; the "yup" value is unimportant.
        // }

        if ((null != gs_ReplaceToken) && (oSession.url.indexOf(gs_ReplaceToken)>-1)) {   // Case sensitive
            oSession.url = oSession.url.Replace(gs_ReplaceToken, gs_ReplaceTokenWith);
        }
        if ((null != gs_OverridenHost) && (oSession.host.toLowerCase() == gs_OverridenHost)) {
            oSession["x-overridehost"] = gs_OverrideHostWith;
        }

        if ((null!=bpRequestURI) && oSession.uriContains(bpRequestURI)) {
            oSession["x-breakrequest"]="uri";
        }

        if ((null!=bpMethod) && (oSession.HTTPMethodIs(bpMethod))) {
            oSession["x-breakrequest"]="method";
        }

        if ((null!=uiBoldURI) && oSession.uriContains(uiBoldURI)) {
            oSession["ui-bold"]="QuickExec";
        }

        if (m_SimulateModem) {
            // Delay sends by 300ms per KB uploaded.
            oSession["request-trickle-delay"] = "300";
            // Delay receives by 150ms per KB downloaded.
            oSession["response-trickle-delay"] = "150";
        }

        if (m_DisableCaching) {
            oSession.oRequest.headers.Remove("If-None-Match");
            oSession.oRequest.headers.Remove("If-Modified-Since");
            oSession.oRequest["Pragma"] = "no-cache";
        }

        // User-Agent Overrides
        if (null != sUA) {
            oSession.oRequest["User-Agent"] = sUA;
        }

        if (m_Japanese) {
            oSession.oRequest["Accept-Language"] = "ja";
        }

        if (m_AutoAuth) {
            // Automatically respond to any authentication challenges using the
            // current Fiddler Classic user's credentials. You can change (default)
            // to a domain\\username:password string if preferred.
            //
            // WARNING: This setting poses a security risk if remote
            // connections are permitted!
            oSession["X-AutoAuth"] = "(default)";
        }

        if (m_AlwaysFresh && (oSession.oRequest.headers.Exists("If-Modified-Since") || oSession.oRequest.headers.Exists("If-None-Match")))
        {
            oSession.utilCreateResponseAndBypassServer();
            oSession.responseCode = 304;
            oSession["ui-backcolor"] = "Lavender";
        }
    }

    // If a given session has response streaming enabled, then the OnBeforeResponse function
    // is actually called AFTER the response was returned to the client.
    //
    // In contrast, this OnPeekAtResponseHeaders function is called before the response headers are
    // sent to the client (and before the body is read from the server).  Hence this is an opportune time
    // to disable streaming (oSession.bBufferResponse = true) if there is something in the response headers
    // which suggests that tampering with the response body is necessary.
    //
    // Note: oSession.responseBodyBytes is not available within this function!
    static function OnPeekAtResponseHeaders(oSession: Session) {
        //FiddlerApplication.Log.LogFormat("Session {0}: Response header peek shows status is {1}", oSession.id, oSession.responseCode);
        if (m_DisableCaching) {
            oSession.oResponse.headers.Remove("Expires");
            oSession.oResponse["Cache-Control"] = "no-cache";
        }

        if ((bpStatus>0) && (oSession.responseCode == bpStatus)) {
            oSession["x-breakresponse"]="status";
            oSession.bBufferResponse = true;
        }

        if ((null!=bpResponseURI) && oSession.uriContains(bpResponseURI)) {
            oSession["x-breakresponse"]="uri";
            oSession.bBufferResponse = true;
        }

    }

    static function OnBeforeResponse(oSession: Session) {
        if (m_Hide304s && oSession.responseCode == 304) {
            oSession["ui-hide"] = "true";
        }
    }

    /** The following snippet demonstrates a custom-bound column for the Web Sessions list (http://fiddler2.com/r/?fiddlercolumns)
    public static BindUIColumn("Method", 60)
    function FillMethodColumn(oS: Session): String {
        return oS.RequestMethod;
    }
    */

    /** The following snippet demonstrates how to create a custom tab that shows simple text
    public BindUITab("Flags")
    static function FlagsReport(arrSess: Session[]): String {
        var oSB: System.Text.StringBuilder = new System.Text.StringBuilder();
        for (var i:int = 0; i<arrSess.Length; i++) {
            oSB.AppendLine("SESSION FLAGS");
            oSB.AppendFormat("{0}: {1}\n", arrSess[i].id, arrSess[i].fullUrl);
            for(var sFlag in arrSess[i].oFlags) {
                oSB.AppendFormat("\t{0}:\t\t{1}\n", sFlag.Key, sFlag.Value);
            }
        }
        return oSB.ToString();
    }
    */

    /** You can create a custom menu like so:
    QuickLinkMenu("&Links")
    QuickLinkItem("IE GeoLoc TestDrive", "http://ie.microsoft.com/testdrive/HTML5/Geolocation/Default.html")
    QuickLinkItem("FiddlerCore", "http://fiddler2.com/fiddlercore")
    public static function DoLinksMenu(sText: String, sAction: String) {
        Utilities.LaunchHyperlink(sAction);
    }
    */

    // This function is called immediately after a set of request headers has
    // been read from the client. This is typically too early to do much useful
    // work, since the body hasn't yet been read, but sometimes it may be useful.
    //
    // For instance, see
    // http://blogs.msdn.com/b/fiddler/archive/2011/11/05/http-expect-continue-delays-transmitting-post-bodies-by-up-to-350-milliseconds.aspx
    // for one useful thing you can do with this handler.
    //
    // Note: oSession.requestBodyBytes is not available within this function!
    static function OnPeekAtRequestHeaders(oSession: Session) {
        // var sProc = ("" + oSession["x-ProcessInfo"]).ToLower();
        // if (!sProc.StartsWith("mylowercaseappname"))
        //     oSession["ui-hide"] = "NotMyApp";
    }

    // This function executes just before Fiddler Classic returns an error that it has
    // itself generated (e.g. "DNS Lookup failure") to the client application.
    // These responses will not run through the OnBeforeResponse function above.
    static function OnReturningError(oSession: Session) {
    }

    // This function executes after Fiddler Classic finishes processing a Session, regardless
    // of whether it succeeded or failed. Note that this typically runs AFTER the last
    // update of the Web Sessions UI listitem, so you must manually refresh the Session's
    // UI if you intend to change it.
    static function OnDone(oSession: Session) {
    }

    static function OnBoot() {
        // MessageBox.Show("Fiddler Classic has finished booting");
        // System.Diagnostics.Process.Start("iexplore.exe");

        // UI.ActivateRequestInspector("HEADERS");
        // UI.ActivateResponseInspector("HEADERS");
    }

    static function OnBeforeShutdown(): Boolean {
        // var count: int = FiddlerApplication.UI.lvSession.TotalItemCount();
        // var result = MessageBox.Show("Allow Fiddler Classic to exit?", "Go Bye-bye?", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
        // return ((0 == count) || (DialogResult.Yes == result));
        return true;    // false will cancel shutdown
    }

    static function OnShutdown() {
        // MessageBox.Show("Fiddler Classic has shutdown");
    }

    static function OnAttach() {
        // MessageBox.Show("Fiddler Classic is now the system proxy");
    }

    static function OnDetach() {
        // MessageBox.Show("Fiddler Classic is no longer the system proxy");
    }

    /** OnExecAction (variables) **/
    static var bpStatus: int = -1;
    static var uiBoldURI: String = null;
    static var gs_ReplaceToken: String = null;
    static var gs_ReplaceTokenWith: String = null;
    static var gs_OverridenHost: String = null;
    static var gs_OverrideHostWith: String = null;

    /** OnExecAction **/
    static function OnExecAction(sParams: String[]): Boolean {

        FiddlerObject.StatusText = "ExecAction: " + sParams[0];

        var sAction = sParams[0].toLowerCase();
        switch (sAction) {
        case "bold":
            if (sParams.Length<2) {uiBoldURI=null; FiddlerObject.StatusText="Bolding cleared"; return false;}
            uiBoldURI = sParams[1]; FiddlerObject.StatusText="Bolding requests for " + uiBoldURI;
            return true;
        case "bp":
            FiddlerObject.alert("bpu = breakpoint request for uri\nbpm = breakpoint request method\nbps=breakpoint response status\nbpafter = breakpoint response for URI");
            return true;
        case "bps":
            if (sParams.Length<2) {bpStatus=-1; FiddlerObject.StatusText="Response Status breakpoint cleared"; return false;}
            bpStatus = parseInt(sParams[1]); FiddlerObject.StatusText="Response status breakpoint for " + sParams[1];
            return true;
        case "bpv":
        case "bpm":
            if (sParams.Length<2) {bpMethod=null; FiddlerObject.StatusText="Request Method breakpoint cleared"; return false;}
            bpMethod = sParams[1].toUpperCase(); FiddlerObject.StatusText="Request Method breakpoint for " + bpMethod;
            return true;
        case "bpu":
            if (sParams.Length<2) {bpRequestURI=null; FiddlerObject.StatusText="RequestURI breakpoint cleared"; return false;}
            bpRequestURI = sParams[1];
            FiddlerObject.StatusText="RequestURI breakpoint for "+sParams[1];
            return true;
        case "bpa":
        case "bpafter":
            if (sParams.Length<2) {bpResponseURI=null; FiddlerObject.StatusText="ResponseURI breakpoint cleared"; return false;}
            bpResponseURI = sParams[1];
            FiddlerObject.StatusText="ResponseURI breakpoint for "+sParams[1];
            return true;
        case "overridehost":
            if (sParams.Length<3) {gs_OverridenHost=null; FiddlerObject.StatusText="Host Override cleared"; return false;}
            gs_OverridenHost = sParams[1].toLowerCase();
            gs_OverrideHostWith = sParams[2];
            FiddlerObject.StatusText="Connecting to [" + gs_OverrideHostWith + "] for requests to [" + gs_OverridenHost + "]";
            return true;
        case "urlreplace":
            if (sParams.Length<3) {gs_ReplaceToken=null; FiddlerObject.StatusText="URL Replacement cleared"; return false;}
            gs_ReplaceToken = sParams[1];
            gs_ReplaceTokenWith = sParams[2].Replace(" ", "%20");  // Simple helper
            FiddlerObject.StatusText="Replacing [" + gs_ReplaceToken + "] in URIs with [" + gs_ReplaceTokenWith + "]";
            return true;
        case "allbut":
        case "keeponly":
            if (sParams.Length<2) { FiddlerObject.StatusText="Please specify Content-Type to retain during wipe."; return false;}
            UI.actSelectSessionsWithResponseHeaderValue("Content-Type", sParams[1]);
            UI.actRemoveUnselectedSessions();
            UI.lvSessions.SelectedItems.Clear();
            FiddlerObject.StatusText="Removed all but Content-Type: " + sParams[1];
            return true;
        case "stop":
            UI.actDetachProxy();
            return true;
        case "start":
            UI.actAttachProxy();
            return true;
        case "cls":
        case "clear":
            UI.actRemoveAllSessions();
            return true;
        case "g":
        case "go":
            // FIXME: resume only the sessions that have been marked or selected
            UI.actResumeAllSessions();
            return true;
        case "goto":
            if (sParams.Length != 2) return false;
            Utilities.LaunchHyperlink("http://www.google.com/search?hl=en&btnI=I%27m+Feeling+Lucky&q=" + Utilities.UrlEncode(sParams[1]));
            return true;
        case "help":
            Utilities.LaunchHyperlink("http://fiddler2.com/r/?quickexec");
            return true;
        case "hide":
            UI.actMinimizeToTray();
            return true;
        case "log":
            FiddlerApplication.Log.LogString((sParams.Length<2) ? "User couldn't think of anything to say..." : sParams[1]);
            return true;
        case "nuke":
            UI.actClearWinINETCache();
            UI.actClearWinINETCookies();
            return true;
        case "screenshot":
            UI.actCaptureScreenshot(false);
            return true;
        case "show":
            UI.actRestoreWindow();
            return true;
        case "tail":
            if (sParams.Length<2) { FiddlerObject.StatusText="Please specify # of sessions to trim the session list to."; return false;}
            UI.TrimSessionList(int.Parse(sParams[1]));
            return true;
        case "quit":
            UI.actExit();
            return true;
        case "dump":
            UI.actSelectAll();
            UI.actSaveSessionsToZip(CONFIG.GetPath("Captures") + "dump.saz");
            UI.actRemoveAllSessions();
            FiddlerObject.StatusText = "Dumped all sessions to " + CONFIG.GetPath("Captures") + "dump.saz";
            return true;

        default:
            if (sAction.StartsWith("http") || sAction.StartsWith("www.")) {
                System.Diagnostics.Process.Start(sParams[0]);
                return true;
            }
            else
            {
                FiddlerObject.StatusText = "Requested ExecAction: '" + sAction + "' not found. Type HELP to learn more.";
                return false;
            }
        }
    }
}