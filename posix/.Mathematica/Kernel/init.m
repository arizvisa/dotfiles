(** User Mathematica initialization file **)

Begin["UserInitializationFile`"]

 (* Remove default directory created in user documents *)
 With[{directory=$UserDocumentsDirectory <> "/Wolfram Mathematica"},
  If[DirectoryQ[directory], DeleteDirectory[directory]]
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
End[]
