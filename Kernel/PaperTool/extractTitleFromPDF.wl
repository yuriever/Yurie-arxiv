(* ::Package:: *)

(* ::Section:: *)
(*Begin*)


BeginPackage["Yurie`PaperTool`extractTitleFromPDF`"];


Needs["Yurie`PaperTool`"];

Needs["Yurie`BlueArXiv`Common`"];


(* ::Section:: *)
(*Public*)


extractTitleFromPDF::usage =
    "extract title from PDF file/directory path.";


extractTitleDataFromPath;


(* ::Section:: *)
(*Private*)


(* ::Subsection:: *)
(*Begin*)


Begin["`Private`"];


(* ::Subsection:: *)
(*Option*)


getTitleDataFromPDF//Options = {
    "HideDirectory"->True,
    "TitleExtractMethod"->"SortYAndFontSize",
    "YResolution"->25
};

extractTitleDataFromPath//Options =
    Options@getTitleDataFromPDF;

extractTitleFromPDF//Options = {
    "ClickToCopy"->True,
    Splice@Options@extractTitleDataFromPath
};


(* ::Subsection:: *)
(*Main*)


extractTitleFromPDF[opts:OptionsPattern[]][path_] :=
    Module[ {fopts},
        fopts =
            FilterRules[{opts,Options[extractTitleFromPDF]},Options[extractTitleDataFromPath]];
        path//extractTitleDataFromPath[fopts]//ifAddButton[OptionValue["ClickToCopy"],"Title"]//Dataset
    ];


(* ::Subsection:: *)
(*Helper*)


extractTitleDataFromPath[opts:OptionsPattern[]][path_] :=
    path//getPDFListFromPath//Map[getTitleDataFromPDF[opts]]//Query[SortBy[#FileName&]];


getTitleDataFromPDF[opts:OptionsPattern[]][file_] :=
    Module[ {title},
        title =
            file//recognizeTitleFromPDFBy[OptionValue["TitleExtractMethod"],OptionValue["YResolution"]]//regulateTitle;
        If[ OptionValue["HideDirectory"],
            <|"Title"->title,"FileName"->hideDirectory[file]|>,
            (*Else*)
            <|"Title"->title,"FileName"->{file}|>
        ]
    ];


(*search grouped texts with larger Y coordinate and fontsize.*)
recognizeTitleFromPDFBy["SortYAndFontSize",yresolution_][file_] :=
    Module[ {textData,counter,resultTextData,searchFirstNTexts},
        textData =
            file//tryImport[{Text[""]},{"PagePositionedText",1}]//regulateTextList[yresolution];
        searchFirstNTexts[data_List,n_] :=
            Intersection[
                data//Query[ReverseSortBy[#Y&]]//Query[1;;n],
                data//Query[ReverseSortBy[#FontSize&]]//Query[1;;n]
            ];
        counter = 1;
        If[ textData==={},
            resultTextData = {},
            While[
                (resultTextData = searchFirstNTexts[textData,counter])==={},
                counter++
            ]
        ];
        (*if there are multiple texts, select one with longest #string.*)
        resultTextData//Query[MaximalBy[StringLength[#string]&]]//Query[1,#string&]
    ];

recognizeTitleFromPDFBy["SumYAndFontSize",yresolution_][file_] :=
    Module[ {textData,maxY,maxFontSize,resultTextData},
        textData =
            file//tryImport[{Text[""]},{"PagePositionedText",1}]//regulateTextList[yresolution];
        maxY =
            textData//Query[All,#Y&]//Max;
        maxFontSize =
            textData//Query[All,#FontSize&]//Max;
        resultTextData =
            textData//Query[All,<|#,"weight"->(#Y/maxY+#FontSize/maxFontSize)|>&]//Query[MaximalBy[#weight&]];
        (*if there are multiple texts, select one with longest #string.*)
        resultTextData//Query[MaximalBy[StringLength[#string]&]]//Query[1,#string&]
    ];


regulateTextList[yresolution_][text_Text] :=
    text//ReplaceAll[
        Text[Style[string_String,_,styleOptions___Rule],coords_List,offset_List]:>
            KeyMap[ToString]@<|
                "string"->string,
                FilterRules[{styleOptions},{FontSize}],
                "X"->coords[[1]],
                "Y"->Round[coords[[2]],yresolution],
                "offset"->offset
            |>
    ];

regulateTextList[yresolution_][textList_List] :=
    Module[ {textData},
        textData =
            regulateTextList[yresolution]/@textList;
        GatherBy[textData,#Y&]//Map[SortBy[#X&]]//Map[mergeDataByKey[{"string"->StringJoin,"X"->Min},First]]
    ];


hideDirectory[file_] :=
    getFileNameByExtension["pdf"][file];


getPDFListFromPath[path_] :=
    getFilePathByExtension["pdf"][path];


regulateTitle//Attributes =
    {Listable};

regulateTitle[""] =
    "";

regulateTitle[arg_Missing] :=
    arg;

regulateTitle[string_String] :=
    string//StringSplit//Map[toLowerCase/*capitalize/*regulateFileName]//StringRiffle;


toLowerCase[string_] :=
    If[ Not@LowerCaseQ[string],
        ToLowerCase[string],
        (*Else*)
        string
    ];


capitalize[string_String] :=
    (*ignore the stop words.*)
    If[ DeleteStopwords[#]==#&[string],
        (*deal with hyphenated names.*)
        StringSplit[string,"-"]//Capitalize//StringRiffle[#,"-"]&,
        (*Else*)
        string
    ];


(* ::Subsection:: *)
(*End*)


End[];


(* ::Section:: *)
(*End*)


EndPackage[];
