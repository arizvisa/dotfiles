(** User Mathematica initialization file **)

Begin["UserInitializationFile`"]

 (** List of items to append to menu **)
 InsertMatchingParenthesesMenuItems := {

 (* Parentheses *)
  MenuItem[
   "Wrap in () and continue at beginning",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"(", "\[SelectionPlaceholder]", ")"}
   ],
   MenuKey["(", Modifiers->{"Control"}]
  ],
  MenuItem[
   "Wrap in () and continue at end",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"(", "\[SelectionPlaceholder]", ")"}
   ],
   MenuKey[")", Modifiers->{"Control"}]
  ],

 (* Braces *)
  MenuItem[
   "Wrap in {} and continue at beginning",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"{", "\[SelectionPlaceholder]", "}"}
   ],
   MenuKey["{", Modifiers->{"Control"}]
  ],
  MenuItem[
   "Wrap in {} and continue at end",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"{", "\[SelectionPlaceholder]", "}"}
   ],
   MenuKey["}", Modifiers->{"Control"}]
  ],

 (* Brackets *)
  MenuItem[
   "Wrap in [] and continue at beginning",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"[", "\[SelectionPlaceholder]", "]"}
   ],
   MenuKey["[", Modifiers->{"Control"}]
  ],
  MenuItem[
   "Wrap in [] and continue at end",
   FrontEndExecute@FrontEnd`NotebookApply[FrontEnd`InputNotebook[],
    BoxData@RowBox@{"[", "\[SelectionPlaceholder]", "]"}
   ],
   MenuKey["]", Modifiers->{"Control"}]
  ]
 }

 (** Add menu items for wrapping expressions **)
 If[$Notebooks,
  FrontEndExecute@
   AddMenuCommands[
    "InsertMatchingParentheses",
    Join[{Delimiter}, InsertMatchingParenthesesMenuItems, {Delimiter}]
   ]
 ]
End[]

Begin["Global`"]
End[]
