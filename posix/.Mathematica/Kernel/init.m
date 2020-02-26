(** User Mathematica initialization file **)

Begin["UserInitializationFile`"]

 (** Utilities for getting the current selections **)
 CurrentText[nb_NotebookObject] := CurrentValue[nb, "SelectionData"]
 CurrentCells[nb_NotebookObject] := Cells[NotebookSelection[nb]]

 (** Extracting/Transforming information from a cell **)
 Contents[cell_CellObject] :=
  Replace[First@NotebookRead[cell], BoxData[row___] -> row]
 WrapText[wrap_List /; (Length[wrap] == 2 && AllTrue[wrap, StringQ]), item_] :=
  RowBox[{First@wrap, item, Last@wrap}]
 WrapCell[wrap_List /; (Length[wrap] == 2 && AllTrue[wrap, StringQ]), cell_] :=
  Contents[cell] /. RowBox[items__] -> RowBox[Join[Take[wrap, 1], items, Rest[wrap]]]

End[]

Begin["Global`"]
 If[$Notebooks,True,True]
End[]
