(** User Mathematica initialization file **)

Begin["UserInitializationFile`"]

 (* Remove default directories created in user documents *)
 With[
  {
   documents = $UserDocumentsDirectory,
   directories = {"Wolfram Mathematica", "Wolfram"}
  },
  Do[
   With[{path = FileNameJoin[documents, directory]},
    If[DirectoryQ[path], DeleteDirectory[path]]
   ],
   {directory, directories}
  ]
 ]

 (** General navigational utilities **)
 NavigationItems = {
  MenuItem["Move up a cell",
   FrontEndExecute@FrontEnd`SelectionMove[FrontEnd`InputNotebook[], Previous, CellContents],
   MenuKey["Up", Modifiers->{"Control"}]
  ],
  (*MenuItem["Move down a cell", "MoveNextCell", MenuKey["Down", Modifiers->{"Control"}]]*)
  MenuItem["Move down a cell",
   FrontEndExecute@FrontEnd`SelectionMove[FrontEnd`InputNotebook[], Next, CellContents],
   MenuKey["Down", Modifiers->{"Control"}]
  ]
 }

 If[$Notebooks,
  FrontEndExecute@
   AddMenuCommands[
    "CellMerge",
    Join[{Delimiter}, NavigationItems, {Delimiter}]
   ]
 ]

 (** Utilities for cuddling menu item handlers *)
 CuddleMenuItem[description_String, key_MenuKey, left_String, right_String] :=
  MenuItem[
   description,
   FrontEndExecute@FrontEnd`NotebookApply[
    FrontEnd`InputNotebook[],
    BoxData@RowBox@{left, "\[SelectionPlaceholder]", right}
   ],
   key
  ]

 (** List of cuddle-related items to append to menu **)
 AvailableCuddleMenuItems = {

 (* Parentheses *)
  CuddleMenuItem["Wrap in () and continue at beginning", MenuKey["(", Modifiers->{"Control"}], "(", ")"],
  CuddleMenuItem["Wrap in () and continue at end", MenuKey[")", Modifiers->{"Control"}], "(", ")"],

 (* Braces *)
  CuddleMenuItem["Wrap in {} and continue at beginning", MenuKey["{", Modifiers->{"Control"}], "{", "}"],
  CuddleMenuItem["Wrap in {} and continue at end", MenuKey["}", Modifiers->{"Control"}], "{", "}"],

 (* Brackets *)
  CuddleMenuItem["Wrap in [] and continue at beginning", MenuKey["[", Modifiers->{"Control"}], "[", "]"],
  CuddleMenuItem["Wrap in [] and continue at end", MenuKey["]", Modifiers->{"Control"}], "[", "]"],

 (* Associations *)
  CuddleMenuItem["Wrap in <||> and continue at beginning", MenuKey["<", Modifiers->{"Control"}], "\[LeftAssociation]", "\[RightAssociation]"],
  CuddleMenuItem["Wrap in <||> and continue at end", MenuKey[">", Modifiers->{"Control"}], "\[LeftAssociation]", "\[RightAssociation]"]
 }

 (** Add menu items for wrapping expressions (cuddling) **)
 If[$Notebooks,
  FrontEndExecute@
   AddMenuCommands[
    "InsertMatchingParentheses",
    Join[{Delimiter}, AvailableCuddleMenuItems, {Delimiter}]
   ]
 ]

End[]

BeginPackage["System`"];
 Spelunk::usage = "Spelunk[symbol] will discover the definition of symbol.  Underlined symbols in the output are clickable.";

 (** Ripped from https://github.com/szhorvat/Spelunking/blob/master/Spelunking.m **)
 Begin["Spelunk`Private`"];
  barrier = "-------"

  defboxes[symbol_Symbol] := Hold[symbol] /. _[sym_] :>
   If[MemberQ[Attributes[sym], Locked],
    "Locked",
    Internal`InheritedBlock[{sym},
     Unprotect[sym]; ClearAttributes[sym, ReadProtected];
     Quiet@Check[ToBoxes[Definition@sym], "DefError"] /.
      InterpretationBox[a_, b___] :> a
    ]
  ]

  defboxes[s_String] := defboxes[#]& @ ToExpression[s, InputForm, Unevaluated]

  prettyboxes[boxes_] :=
   boxes (* /. {" "} -> {barrier<>"\n"} *) //. {
    RowBox[{left___, ";", next : Except["\n"], right___}] :>
     RowBox[{left, ";", "\n", "\t", next, right}],
     RowBox[{sc : ("Block" | "Module" | "With"), "[", RowBox[{vars_, ",", body_}], "]"}] :>
      RowBox[{sc, "[", RowBox[{vars, ",", "\n\t", body}], "]"}]
   }

  fancydefinition[symbol_Symbol] := Cell[BoxData@prettyboxes[
    defboxes[symbol] /.
     s_String?(StringMatchQ[#, __ ~~ "`" ~~ __] &) :>
      First@StringCases[s, a : (__ ~~ "`" ~~ b__) :> processsymbol[a, b]]
   ],
   "Print", "PrintUsage",
   ShowStringCharacters -> True,
   CellGroupingRules->"OutputGrouping",
   GeneratedCell->True,
   CellAutoOverwrite->True,
   ShowAutoStyles->True,
   LanguageCategory->"Mathematica",
   FontWeight->"Bold"
  ]

  processsymbol[a_, b_] := Module[{db},
   Which[
    ! StringFreeQ[a, "\""], a,
    ! StringFreeQ[a, "_"] || (db = defboxes[a]) === "Null",
    TooltipBox[b, a],
    db === "Locked", TooltipBox[b, a <> "\nLocked Symbol"],
    db === "DefError", TooltipBox[b, a <> "\nError getting Definition"],
    True,
    ActionMenuBox[
     TooltipBox[StyleBox[b, FontVariations->{"Underline"->True}], a], {
      "Discover function" :> Spelunk[a],
      "Copy full name" :> CopyToClipboard@Cell[a, "Input"]
     },
     DefaultBaseStyle -> {"InformationLink"},
     Appearance->"None",
     Evaluator -> Automatic
    ]
   ]
  ]

  Spelunk[symbol_Symbol] := CellPrint[fancydefinition[symbol]];
  Spelunk[s_String] := CellPrint[fancydefinition[#]& @ ToExpression[s, InputForm, Unevaluated]];
  SetAttributes[{defboxes, fancydefinition, Spelunk}, HoldFirst]
 End[];

 (** Ripped from https://stackoverflow.com/questions/4198961/what-is-in-your-mathematica-tool-bag **)
 SetAttributes[WithRules, HoldAll]
 WithRules[rules_, expr_] :=
   Internal`InheritedBlock[
     {Rule, RuleDelayed},
     SetAttributes[{Rule, RuleDelayed}, HoldFirst];
     Unevaluated[expr] /. rules
   ]

 (** Ripped from https://stackoverflow.com/questions/4198961/what-is-in-your-mathematica-tool-bag **)
 Options[SelectEquivalents] =
    {
       TagElement->Identity,
       TransformElement->Identity,
       TransformResults->(#2&) (*#1=tag,#2 list of elements corresponding to tag*),
       MapLevel->1,
       TagPattern->_,
       FinalFunction->Identity
    };

 SelectEquivalents[x_List,OptionsPattern[]] :=
    With[
       {
          tagElement=OptionValue@TagElement,
          transformElement=OptionValue@TransformElement,
          transformResults=OptionValue@TransformResults,
          mapLevel=OptionValue@MapLevel,
          tagPattern=OptionValue@TagPattern,
          finalFunction=OptionValue@FinalFunction
       },
       finalFunction[
          Reap[
             Map[
                Sow[transformElement@#, {tagElement@#}] &,
                x,
                {mapLevel}
             ],
             tagPattern,
             transformResults
          ][[2]]
       ]
    ];

 FromBaseForm::usage = "FromBaseForm will return an Integer for a number in BaseForm, a string, or if it is subscripted.";
 FromBaseForm[Subscript[number_, base_Integer]] := FromBaseForm[number // ToString, base];
 FromBaseForm[number_, base_Integer] := FromBaseForm[number // ToString, base];
 FromBaseForm[number_String, base_Integer] :=
   Block[{
     Table = MapIndexed[
       #1 -> #2[[1]] - 1 &,
       "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" //
          Characters //
          #[[;; base]] &
     ] // Association
   },
   With[{
     digits = number //
       ToUpperCase //
       Characters //
       Map[Table[[#]] & ]
   },
     FromDigits[digits, base]
   ]
 ];
 FromBaseForm[BaseForm[number_, base_]] := number;   (* just in case our input isn't just formatting *)
 FromBaseForm[number_String] := With[
   {BaseTable = <|"b" -> 2, "d" -> 10, "x" -> 16, "o" -> 8|>},
   Characters[number] /. {
     {"0", digits__String} /; AllTrue[{digits}, StringMatchQ["01234567" // Characters]] ->
       {{digits}, Lookup[BaseTable, "o"]},
     {"0", x_String, digits__String} /; ToLowerCase[x] == "x" && AllTrue[{digits}, StringMatchQ[HexadecimalCharacter]] ->
       {{digits}, Lookup[BaseTable, "x"]},
     {"0", o_String, digits__String} /; ToLowerCase[x] == "o" && AllTrue[{digits}, StringContainsQ["01234567" // Characters]] ->
       {{digits}, Lookup[BaseTable, "o"]},
     {"0", b_String, digits__String} /; ToLowerCase[b] == "b" && AllTrue[{digits}, StringContainsQ["01" // Characters]] ->
       {{digits}, Lookup[BaseTable, "b"]},
     {"0", d_String, digits__String} /; ToLowerCase[d] == "d" && AllTrue[{digits}, DigitQ] ->
       {{digits}, Lookup[BaseTable, "d"]},
     {zero_String, digits__String} /; AllTrue[{zero, digits}, DigitQ] && StringContainsQ[zero, "123456789" // Characters] ->
       {{zero, digits}, Lookup[BaseTable, "d"]},
     {else___} ->
       {{else}, 0}
   } // Apply[FromBaseForm[StringJoin[#1], #2] &]
 ];

 GraphOfTree[tree_, options___] := Module[
  {count = 0},
  traverse[head_[children___]] := With[
   {id = count},
   {DirectedEdge[id, ++count], traverse[#]}& /@ {children}
  ];
  traverse[_] := Sequence[];
  TreeGraph[traverse[tree] // Flatten, ##]& @ options
 ];

 (** Ripped from https://community.wolfram.com/groups/-/m/t/1678540 **)
 VertexShapeCustom[width_][xy_, vertexname_, wh_] := Inset[
  Framed[
   Pane[Style[vertexname, TextAlignment -> Center], width],
   Background -> RandomColor[],    (* FIXME: It would be better to generate a list of pale colors that we cycle through *)
   RoundingRadius -> 5
  ],
  xy
 ];

 CompilableQ[func_] := MemberQ[Compile`CompilerFunctions[], func];

 (*
   ripped entirely from https://stackoverflow.com/questions/3736942/test-if-an-expression-is-a-function
     because i couldn't get https://stackoverflow.com/questions/4599241/checking-if-a-symbol-is-defined
       to work on delayed symbols, or closures. we ignore upvalues entirely, of course.
 *)
 FunctionQ[expr_] := Module[
  {symbolic, partial, function},

  (* once we traverse to a symbol, we straight-up check everything. *)
  SetAttributes[symbolic, HoldAllComplete];
  symbolic[_Function | _InterpolatingFunction | _CompiledFunction] = True;
  symbolic[symbol_Symbol] /; symbol =!= Symbol := Or[
   SubValues[symbol] =!= {},
   DownValues[symbol] =!= {},
   MemberQ[Attributes[symbol], NumericFunction]
  ];
  symbolic[_] = False;

  (* if we didn't recurse into a symbol, then it might be partially evaluated. *)
  SetAttributes[partial, HoldAllComplete];
  partial[symbol_Symbol[___]] := partial[symbol];
  partial[symbol_[___]] := partial[symbol];
  partial[symbol_] := symbolic@symbol;

  (* start by testing all of the obvious things before trying partial-evaluation. *)
  SetAttributes[function, HoldAllComplete];
  function[_Function | _InterpolatingFunction | _CompiledFunction] = True;
  function[symbol_Symbol] /; symbol =!= Symbol := symbolic@symbol;
  function[notsymbol_Symbol] /; notsymbol === Symbol = False;
  function[nothead_] := partial[nothead];

  Return[function[expr]]
 ];

 (** Copied from ResourceFunction["PersistResourceFunction"]. **)
 (** This is copied since the original implementation is not entirely compatible with 14.x and uses the Global` context by default.  **)
 Options[PersistResourceFunction] := {
  "PersistenceLocation" :> $PersistenceBase,
  (*
   For possible future use. It would be ideal to store all installed resource
   functions in their own context to avoid conflicts, but I don't know of a
   way to automatically load such a context into $ContextPath at kernel start.
   ($InitializationContexts sounds like such a feature but it's not.)
  *)
  "Context" -> "System`"
 };

 (* Pattern for a list *)
 PersistResourceFunction[list : {(_ResourceFunction | _String) ...}, rest___, opts : OptionsPattern[]] := PersistResourceFunction[#, rest, opts] & /@ list;

 (* Pattern for installation *)
 PersistResourceFunction /: PersistResourceFunction[action : ("Install" | "Uninstall"), opts : OptionsPattern[]][expr_] := PersistResourceFunction[expr, action, opts];

 (* Pattern for failure due to unknown function *)
 PersistResourceFunction[ funcName_String?(FreeQ[ "Install" | "Uninstall" | "List" | "UninstallAll"]), rest___, opts : OptionsPattern[]] := Check[
  PersistResourceFunction[ResourceFunction[funcName], rest, opts],
  Failure[ "ResourceFunctionNotFound",
   <|
    "MessageTemplate" :> "The ResourceFunction \"`func`\" could not be found.",
    "MessageParameters" -> <|"func" -> funcName|>
   |>
  ], {ResourceAcquire::apierr}
 ];

 (* Pattern for uninstalling all persisted functions *)
 PersistResourceFunction["UninstallAll", opts : OptionsPattern[]] := PersistResourceFunction["Uninstall"][PersistResourceFunction["List"]];

 (* Pattern for installation given a string *)
 PersistResourceFunction[func_ResourceFunction, opts : OptionsPattern[]] := PersistResourceFunction[func, "Install", opts];

 (* List all persisted resource functions *)
 (* FIXME: Using `Extract` with parts {1,1,1} and {1,1} is unreliable and can change between versions *)
 PersistResourceFunction["List", opts : OptionsPattern[]] := With[
  {context = OptionValue["Context"], persistenceLocation = OptionValue["PersistenceLocation"]},
  Extract[#["HeldValue"], {1, 1, 1}]& /@
   Select[
    InitializationObjects[Evaluate[context <> "*"], persistenceLocation],
    Head@Extract[#["HeldValue"], {1, 1}] === ResourceFunction &
   ]
  // Sort
 ];

 (* Install or update a resource function by name *)
 PersistResourceFunction[func_ResourceFunction, "Install" | "Update", OptionsPattern[]] := Module[
  {
     resourceObj = ResourceObject@func,
     persistenceLocation = OptionValue["PersistenceLocation"],
     shortName,
     result
  },
  shortName = ResourceFunction[resourceObj, "ShortName"];
  result = Check[
   With[
    {
     symbolString = OptionValue["Context"] <> shortName,
     $persistenceLocation = persistenceLocation
    },
    Quiet@Remove@symbolString;
    Block[{ResourceFunction}, InitializationValue[symbolString, $persistenceLocation] = ResourceFunction[func, "Function"]];
    Initialize[symbolString, {$persistenceLocation}]
   ], $Failed
  ];
  If[ ! FailureQ@result,
   Success["InstalledResourceFunction",
    <|"MessageTemplate" :>
     "Successfully stored `symName` as an initialization symbol.",
     "MessageParameters" -> <|"symName" -> shortName|>,
     "PersistenceLocation" -> Replace[s_String :> PersistenceLocation[s]]@persistenceLocation|>
   ], Failure["InstallationFailure",
    <| "MessageTemplate" :>
     "A failure occurred in attempting to store `symName` as an initialization symbol.",
     "MessageParameters" -> <|"symName" -> shortName|>
    |>
   ]
  ]
 ];

 (* Uninstall a resource function by name *)
 PersistResourceFunction[func_ResourceFunction, "Uninstall", OptionsPattern[]] := Module[
  {
   resourceObj = ResourceObject@func,
   persistenceLocation = OptionValue["PersistenceLocation"],
   shortName,
   result
  },
  shortName = ResourceFunction[resourceObj, "ShortName"];
  If[ ! NameQ[shortName] || Length[InitializationObjects[ Evaluate[OptionValue["Context"] <> shortName], persistenceLocation]] === 0,
   Return@ Failure["InitializationValueDoesNotExist",
    <|
     "MessageTemplate" :> "No initialization symbol definition for `symName` could be removed because no such definition exists.",
     "MessageParameters" -> <|"symName" -> shortName|>
    |>
   ]
  ];
  result = Check[
   With[
    {
     symbolString = OptionValue["Context"] <> shortName,
     $persistenceLocation = persistenceLocation
    },
    Remove@InitializationValue[symbolString, $persistenceLocation];
    Quiet@Remove@symbolString;
   ], $Failed
  ];
  If[ ! FailureQ@result,
   Success["UninstalledResourceFunction",
    <|
     "MessageTemplate" :> "Successfully removed the initialization symbol definition for `symName`.",
     "MessageParameters" -> <|"symName" -> shortName|>,
     "PersistenceLocation" -> Replace[s_String :> PersistenceLocation[s]]@persistenceLocation
    |>
   ], Failure[ "UninstallationFailure",
    <|
     "MessageTemplate" :> "A failure occurred in attempting to remove the initialization symbol definition for `symName`.",
     "MessageParameters" -> <|"symName" -> shortName|>
    |>
   ]
  ]
 ];

EndPackage[];

(** Default global options **)
Begin["Global`"]
 If[$FrontEnd =!= Null,
  SetOptions[$FrontEnd, ShowAtStartup->NewDocument];
  SetOptions[$FrontEnd, CellContext->Notebook];
  SetOptions[$FrontEnd, NumberMarks->True];
  SetOptions[$FrontEnd, RenderingOptions->{"HardwareAntialiasingQuality" -> 0.}];
  SetOptions[$FrontEnd, StyleNameDialogSettings->{"Style" -> "CodeText"}];
 ];

 (** Packages that are useful to have **)
 Quiet[Needs["PacletManager`"]]
 Quiet[Needs["IGraphM`"]]
End[]
