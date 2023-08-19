(* ::Package:: *)

(* ::Section:: *)
(*Begin*)


BeginPackage["Yurie`BlueArXiv`common`"];


(* ::Section:: *)
(*Usage*)


(* ::Subsection:: *)
(*Common symbols*)


$arXivIDPattern::usage = 
    "string pattern of valid arXiv ID.";

$arXivPDFNameFormatter::usage = 
    "formatter of file names, set by arXivPDFNameFormat.";
$arXivPDFNameRegulator::usage = 
    "regulator of file names, set by arXivPDFNameFormat.";

$defaultDownloadDir::usage = 
    "default download directory";
$defaultBibName::usage = 
    "default BibTeX file name.";

$citeKeyPattern::usage = 
    "string pattern of cite key.";    


(* ::Subsection:: *)
(*Common functions*)


regulateFileName::usage = 
    "regulate special characters in file name.";
    
getFileByExtension::usage = 
    "get files in path or list of paths by specifying the extension.";
getFileNameByExtension::usage =
    "get file names in path or list of paths by specifying the extension.";

ifAddButtonTo::usage = 
    "whether to add click-to-copy button to list of associations.";
addButtonTo::usage = 
    "add click-to-copy button to list of associations.";

mergeByKey::usage =
    "ResourceFunction[\"MergeByKey\"]: merge a list of associations using different merge functions according to keys. The default merging function is Identity.\n"<>
    "mergeByKey[{assoc1,assoc2,...},{key1->f1,key2->f2,...},f]\n"<>
    "mergeByKey[{assoc1,assoc2,...},{...,{keyi1,keyi2,...}->fi,...},...]";


(* ::Section:: *)
(*Private*)


(* ::Subsection:: *)
(*Begin*)


Begin["`Private`"];


(* ::Subsection:: *)
(*Common symbols*)


$arXivIDPattern =
    RegularExpression["(\\d{4}\\.\\d{4,5})|((astro-ph|cond-mat|gr-qc|hep-ex|hep-lat|hep-ph|hep-th|math-ph|nlin|nucl-ex|nucl-th|physics|quant-ph|math|cs)/\\d{7})"];


$arXivPDFNameFormatter =
    (*set the default format of PDF names.*)
    (*arXivPDFNameFormat["ID"<>" "<>"title"<>", "<>"firstAuthor"]*)
    (
        Lookup[#,"ID"]<>" "<>
        Lookup[#,"Title",""]<>", "<>
        Lookup[#,"Author","",Part[#,1,"Name"]&]
    )&;


(*set the default regulator of PDF names.*)
$arXivPDFNameRegulator =
    regulateFileName;


$defaultDownloadDir :=
    FileNameJoin@{$HomeDirectory,"Downloads"};


$defaultBibName :=
    "refs-"<>CreateUUID[]<>".bib";


$citeKeyPattern = 
    (*no whitespace tolerance.*)
    RegularExpression["(\\\\cite{)(\\S*?)(})"];


(* ::Subsection:: *)
(*regulateFileName*)


regulateFileName[string_String] :=
    RemoveDiacritics@StringReplace[
        string,
        {    
            ":"->" -",     
            "/"->"_",
            "\n"|"\r"->" ",
            "\[CloseCurlyQuote]"->"'"
        }
    ];


(* ::Subsection:: *)
(*getFileByExtension|getFileNameByExtension*)


getFileByExtension[extension_][path_] :=
    `getFileByExtension`kernel[extension][path];

getFileByExtension[extension_][pathList_List] :=
    `getFileByExtension`kernel[extension]/@pathList//Flatten//DeleteDuplicates;


`getFileByExtension`kernel[extension_][path_] :=
    Which[
        DirectoryQ[path],
            FileNames[__~~"."~~extension~~EndOfString,path],
        FileExistsQ[path]&&FileExtension[path]===extension,
            {path},
        True,
            {}
    ];


getFileNameByExtension[extension_][pathOrPathList_] :=
    getFileByExtension[extension][pathOrPathList]//Map[FileNameTake]//Map[FileBaseName];


(* ::Subsection:: *)
(*addButtonTo*)


ifAddButtonTo[True][list:{___String}] :=
    `addButtonTo`copyToClipboard/@list;

ifAddButtonTo[True,keys__][list:{___Association}] :=
    addButtonTo[keys][list];

ifAddButtonTo[False,___][list_] :=
    list;


addButtonTo[key_String][list_] :=
    With[ {$$key = key},
        list//Query[All,<|#,$$key->`addButtonTo`copyToClipboard[Slot[$$key]]|>&]
    ];

addButtonTo["URL"][list_] :=
    list//Query[All,<|#,"URL"->`addButtonTo`hyperlink[#URL]|>&];

addButtonTo[key_,restKeys__][list_] :=
    list//addButtonTo[key]//addButtonTo[restKeys];


`addButtonTo`hyperlink[value_String] :=
    Hyperlink[value,value,FrameMargins->Small];

`addButtonTo`hyperlink[_] :=
    Missing["Failed"];


`addButtonTo`copyToClipboard[value_] :=
    Interpretation[{},
        Button[value,CopyToClipboard@value,Appearance->"Frameless",FrameMargins->Small],
        value
    ];

`addButtonTo`copyToClipboard[_Missing] :=
    Missing["Failed"];


(* ::Subsection:: *)
(*mergeByKey*)


mergeByKey[ruleList:{___Rule},default:_:Identity][data:{___?AssociationQ}] :=
    mergeByKey[data,ruleList,default];

mergeByKey[{<||>...},{___Rule},Repeated[_,{0,1}]] :=
    <||>;

mergeByKey[data:{__?AssociationQ},ruleList:{___Rule},default:_:Identity] :=
    Module[ {missingToken,assoc,keys,queryRules,mergeRules},
        (*missingToken: unique symbol that is used for identifying where the undefined keys were after transposing the association *)
        mergeRules = 
            Replace[
                Flatten@Replace[
                    ruleList,
                    Verbatim[Rule][list_List,fun_]:>Thread[list->fun],
                    {1}
                ],
                Verbatim[Rule][Key[k_],fun_]:>Rule[k,fun],
                {1}
            ];
        (*avoid KeyUnion if it's not necessary.*)
        If[ SameQ@@Keys[data],
            assoc = data,
            assoc = KeyUnion[DeleteCases[data,<||>],missingToken&]
        ];
        keys = Keys@First@assoc;
        (*this is essentially how GeneralUtilities`AssociationTranspose works.*)
        assoc = 
            AssociationThread[
                keys,
                If[ SameQ@@Keys[data],
                    Transpose@Values[assoc],
                    DeleteCases[Transpose@Values[assoc],missingToken,{2}]
                ]
            ];
        keys = Key/@keys;
        queryRules = 
            DeleteCases[
                Thread[
                    keys->Lookup[mergeRules,keys,default]
                ],
                _->Identity
            ];
        If[ MatchQ[queryRules,{__Rule}],
            Query[queryRules]@assoc,
            assoc
        ]
    ];


(* ::Subsection:: *)
(*End*)


End[];


(* ::Section:: *)
(*End*)


EndPackage[];
