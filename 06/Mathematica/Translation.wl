(* ::Package:: *)

BeginPackage["Translation`"]

Translation::usage =
        "Translation[text_] is a function that takes in a text string 
         of the Hack Assembly language format as input to deliver text 
		 string input in the Machine code format."

TranslateHackCodeWithUpdatedSymbols::usage = 
		"TranslateHackCodeWithUpdatedSymbols[text_, SymbolTable_] is a function that will first read
         the original source code and add new symbols to the SymbolTable, then produce Hack machine code
         as output."

SymbolTable::usage =
        "SymbolTable is a Hack Computer specific dictionary that is used to look up variable names in Assembly code."

Begin["`Private`"]


(* This file is dedicated to translate Hack assembly code to Hack machine code *)
(* The following information are specific to the architecture of Hack Computer *)

(* Two types of instructions,    
 A Instruction and C Instruction *)
AInstructionDecimalBase=0;
AInstructionBase=NumberDecompose[AInstructionDecimalBase,Table[10^i,{i,15,0,-1}]];
CInstructionDecimalBase=1110000000000000;
CInstructionBase=NumberDecompose[CInstructionDecimalBase,Table[10^i,{i,15,0,-1}]];

(* For C Instructions, the following "compLookupTable" table for easy transcribing from the book. *)
 

compLookupTable=
{{"0",0101010},
{"1",0111111},
{"-1",0111010},
{"D",0001100},
{"A",0110000},
{"M",1110000},
{"!D",0001101},
{"!A",0110001},
{"!M",1110001},
{"-D",0001111},
{"-A",0110011},
{"-M",1110011},
{"D+1",0011111},
{"A+1",0110111},
{"M+1",1110111},
{"D-1",0001110},
{"A-1",0110010},
{"M-1",1110010},
{"D+A",0000010},
{"D+M",1000010},
{"D-A",0010011},
{"D-M",1010011},
{"A-D",0000111},
{"M-D",1000111},
{"D&A",0000000},
{"D&M",1000000},
{"D|A",0010101},
{"D|M",1010101}
};

(* Now, turn this into a set of binary valued decimal vectors *)
COMPBITREPRESENTATION=Map[NumberDecompose[#,Table[10^i,{i,6,0,-1}]]&, Transpose[compLookupTable][[2]]];

(* Now, convert this into a format that would be easy for later transformation *)
CompInstructionTable =Drop[Insert[compLookupTable//Transpose, COMPBITREPRESENTATION,2],-1]//Transpose;

(* For C Instructions' destination information, the following "destLookupTable" table for easy transcribing from the book. *)
destLookupTable={
{"null",000},
{"M",001},
{"D",010},
{"MD",011},
{"A",100},
{"AM",101},
{"AD",110},
{"AMD",111}
};

(* Now, turn this into a set of binary valued decimal vectors *)
DESTBITREPRESENTATION=Map[NumberDecompose[#,Table[10^i,{i,2,0,-1}]]&, Transpose[destLookupTable][[2]]];

(* Now, convert this into a format that would be easy for later transformation *)
DestInstructionTable =Drop[Insert[destLookupTable//Transpose, DESTBITREPRESENTATION,2],-1]//Transpose;

(* For C Instructions' jump location instructions, the following "jumpLookupTable" table for easy transcribing from the book. *)
jumpLookupTable={
{"null",000},
{"JGT",001},
{"JEQ",010},
{"JGE",011},
{"JLT",100},
{"JNE",101},
{"JLE",110},
{"JMP",111}
};
(* Now, turn this into a set of binary valued decimal vectors *)
JUMPBITREPRESENTATION=Map[
	NumberDecompose[#,Table[10^i,{i,2,0,-1}]]&, 
	Transpose[jumpLookupTable][[2]]
];

(* Now, convert this into a format that would be easy for later transformation *)
JumpInstructionTable =Drop[Insert[jumpLookupTable//Transpose, JUMPBITREPRESENTATION,2],-1]//Transpose;

(** Starting from here, we put in A instructions **)
(* For A Instructions' predefined addresses, the following "SymbolTable" table for easy transcribing from the book. *)

SymbolTable={
{"SP",0},
{"LCL",1},
{"ARG",2},
{"THIS",3},
{"THAT",4},
{"R0",0},
{"R1",1},
{"R2",2},
{"R3",3},
{"R4",4},
{"R5",5},
{"R6",6},
{"R7",7},
{"R8",8},
{"R9",9},
{"R10",10},
{"R11",11},
{"R12",12},
{"R13",13},
{"R14",14},
{"R15",15},
{"SCREEN",16384},
{"KBD",24567}
};

(* After typying in all the given information, these keywords are put into these keyword collections *)
DestinationCollection=Transpose[DestInstructionTable][[1]];
CompCollection=Transpose[CompInstructionTable][[1]];
JumpCollection=Transpose[JumpInstructionTable][[1]];

(* Given these keywords, create the replacement rule collections*)
JumpReplacementRule=MapThread[Rule, Transpose[JumpInstructionTable]];
DestinationReplacementRule=MapThread[Rule, Transpose[DestInstructionTable]];
CompInstructionReplacementRule=MapThread[Rule, Transpose[CompInstructionTable]];

(* Given an A instruction inst_, return its binary string representation. *)
addressCommand[inst_] := Module[ 
	{ vectAInstruction, addressDecimalValue,splitted,i, debug },
		vectAInstruction=AInstructionBase;
		addressDecimalValue=0;
		splitted={};
		i=0;
		debug=False;


		splitted=StringSplit[inst,"@"]//First;
		If[StringMatchQ[splitted,NumberString],
		addressDecimalValue= ToExpression[splitted],
		If[debug,Print["To be used to look up address"<> splitted]];
		addressDecimalValue=splitted /. MapThread[Rule, Transpose[SymbolTable]]];
		vectAInstruction=
			NumberDecompose[addressDecimalValue, 
					Table[2^i,{i,15,0,-1}]];StringJoin[Map[ToString, vectAInstruction]]
]

(* Given an A instruction inst_, return its binary string representation. *)
addressCommandWithUpdatedSymbols[inst_, symbolTable_] := 
Module[
(** This function is for translating A Instructions **)
{
vectAInstruction=AInstructionBase,
addressDecimalValue=0,
splitted={},
updatedSymbols=symbolTable,
i=0,
debug= False
},

splitted=StringSplit[inst,"@"]//First;
If[StringMatchQ[splitted,NumberString],
addressDecimalValue= ToExpression[splitted],
If[debug, Print["To be used to look up address:"<> splitted]];
addressDecimalValue=splitted /. MapThread[Rule, Transpose[updatedSymbols]]];
vectAInstruction=NumberDecompose[addressDecimalValue, Table[2^i,{i,15,0,-1}]];StringJoin[Map[ToString, vectAInstruction]]
]

(* Given a C instruction inst_, return its binary string representation. *)
compCommand[inst_] := Module[
(** This function is for translating COMP commands **)
{localCInstruction=Null,
vectCInstruction=CInstructionBase,
splitted={},
comp={},
dest={}
},

If[Length[StringSplit[inst,"="]]== 2,
splitted=StringSplit[inst,"="];
(* Print[splitted]; *)

comp=Last[splitted] /. CompInstructionReplacementRule;
(* Print[comp]; *)
dest=First[splitted] /. DestinationReplacementRule;
vectCInstruction= ReplacePart[vectCInstruction, {4-> comp[[1]], 5-> comp[[2]],6-> comp[[3]],
     		7-> comp[[4]], 8-> comp[[5]],9-> comp[[6]],10-> comp[[7]]}];
vectCInstruction=ReplacePart[vectCInstruction, {11-> dest[[1]], 12-> dest[[2]],13-> dest[[3]]}];localCInstruction= StringJoin[Map[ToString, vectCInstruction]];
, Print["Not a comp instruction"]];
 localCInstruction
]

(* Given a JUMP C instruction inst_, return its binary string representation. *)
jumpCommand[inst_] := Module[
(** This function is for translating JUMP commands **)
{localCInstruction=Null,
vectCInstruction=CInstructionBase,
splitted={},
jump={},
comp={}
},

If[Length[StringSplit[inst,";"]]== 2,
splitted=StringSplit[inst,";"];

jump=Last[splitted] /. JumpReplacementRule;
comp=First[splitted] /. CompInstructionReplacementRule;

vectCInstruction= ReplacePart[vectCInstruction,{14-> jump[[1]], 15-> jump[[2]],16-> jump[[3]]}];

vectCInstruction= ReplacePart[vectCInstruction, {4-> comp[[1]], 5-> comp[[2]],6-> comp[[3]],
     		7-> comp[[4]], 8-> comp[[5]],9-> comp[[6]],10-> comp[[7]]}];

, Print["Not a jump instruction"]];

localCInstruction= StringJoin[Map[ToString, vectCInstruction]];
localCInstruction
]

(* Given a C instruction inst_, send it to either compCommand or jumpCommand, so that it will return the proper binary string representation. *)
CCommandTranslate[inst_]:=
If[Length[StringSplit[inst,"="]]== 2,compCommand[inst],jumpCommand[inst]]


(** Starting from here, we will process the text information coming from ASM files **)
IsEmptyLineQ[line_]:=If[StringLength[StringTrim[line]]==0,True, False];
IsAInstructionQ[line_]:=StringStartsQ[line, "@"];
IsCInstructionQ[line_]:=Or[StringMatchQ[line,RegularExpression["[AMD]{1,3}=-?!?[AMD10][+-]?[&]?[|]?[AMD10]?"]],
StringMatchQ[line,RegularExpression["[AMD0];(JGT|JEQ|JGE|JLT|JNE|JLE|JMP)"]]];
IsCommentedLineQ[line_]:= StringMatchQ[StringTrim[line], "//*"];

(* The following code create an array that just produce an array with instructions.*)
CollectInstruction[textLineArray_]:=
Module[
 {n, dropCandidatesArray},
   (* Initialize local variables *)
	n=1;
	dropCandidatesArray={};

	While[n<=Length[textLineArray],
	If[StringTrim[textLineArray[[n]]]=="",
	(* THEN *)
	(* Print["-----Empty String-----"],*)
	AppendTo[dropCandidatesArray,{n}],
	(* ELSE *)
	If[ StringStartsQ[textLineArray[[n]], "//"],
	(* THEN *)
	(*Print["Is Comment String:   " <>textLineArray\[LeftDoubleBracket]n\[RightDoubleBracket] ] *)
	AppendTo[dropCandidatesArray,{n}]
	]
	]
	n++ ];
	Delete[textLineArray,dropCandidatesArray ]
]

(* This function starts the translation and returns an array of binary strings. *)
TranslateInstruction[assemblyArray_]:=
Module[{emptyArray={}, n=1},
While[n<=Length[assemblyArray],

If[IsAInstructionQ[assemblyArray[[n]]],
AppendTo[emptyArray, addressCommand[assemblyArray[[n]]]],

If[IsCInstructionQ[assemblyArray[[n]]],
AppendTo[emptyArray, CCommandTranslate[assemblyArray[[n]]]],
Print["Not a C instruction:"<> assemblyArray[[n]]]
],
Print["Not an A Instruction"]
];
n++ 
];
Return[emptyArray];
]

TranslateInstructionWithUpdatedSymbols[assemblyArray_, symbolTable_]:=

	Module[{ emptyArray={}, updatedSymbols=symbolTable,n=1 },

		While[n<=Length[assemblyArray],
		If[IsAInstructionQ[assemblyArray[[n]]],
               AppendTo[emptyArray, addressCommandWithUpdatedSymbols[assemblyArray[[n]],updatedSymbols]],

				If[IsCInstructionQ[assemblyArray[[n]]],
					AppendTo[emptyArray, CCommandTranslate[assemblyArray[[n]]]],
					Print["Not a C instruction:"<> assemblyArray[[n]]]
				],
				Print["Not an A Instruction"]
		];
		n++ 
		];
	Return[emptyArray];
	]


(* Go through textLineArray and create a new symbolTable as well as a Label removal array.*)
CollectLabels[textLineArray_, symbolTable_]:=
Module[
  {n, romAddress, labelCandidatesIndexArray, labelCandidatesArray, labelCandidate},
	n=1;
	romAddress =1;
	labelCandidatesIndexArray={};
	labelCandidatesArray=symbolTable;
	labelCandidate="";

	While[n<=Length[textLineArray],
	If[ StringStartsQ[textLineArray[[n]], "("],
	(* THEN *)
	romAddress=romAddress-1;
	labelCandidate =StringDrop[StringDrop[textLineArray[[n]],1],-1];
	If[MemberQ[Transpose[labelCandidatesArray][[1]],labelCandidate ],
	(* If this is a member of SymbolTable, then, don't do anything *)
	Print[labelCandidate <> "Already Exists"],
	(* Else if this is a new symbol member,*)
	(* Print["Candidate Label:"<> "Line["<> ToString[n]<>"]" <>labelCandidate<> "->"<> ToString[romAddress]] ; *)
	AppendTo[labelCandidatesArray,{labelCandidate,romAddress}];
	AppendTo[labelCandidatesIndexArray,{n}]
	]
	]
	(* ELSE *)
	romAddress++ 
	n++ ];
	{labelCandidatesArray, labelCandidatesIndexArray}
]

(* Go through textLineArray and create a new symbolTable as well as a Label removal array.*)
CollectRamAddress[textLineArray_, symbolTable_]:=
Module[{n, ramAddress, labelCandidatesIndexArray, updatedSymbols, candidateNewSymbol, debug},
	n=1;
	ramAddress =16;
	labelCandidatesIndexArray={};
	updatedSymbols=symbolTable;
	candidateNewSymbol="";
	debug=False;

	While[n<=Length[textLineArray],
	If[ StringStartsQ[textLineArray[[n]], "@"],
	(* THEN *)
	candidateNewSymbol=StringSplit[textLineArray[[n]],"@"]//First;

	If[StringMatchQ[candidateNewSymbol,NumberString],
	(* THEN *)
	If[debug, Print["Not a new symbol:"<> candidateNewSymbol]],
	(* ELSE *)
	If[MemberQ[Transpose[updatedSymbols][[1]],candidateNewSymbol ],
	(* If this is a member of SymbolTable, then, don't do anything *)
	If[debug, Print[" Already Exists: "<> candidateNewSymbol ]], 
	(* Else if this is a new symbol member,*)
	(*Print["Candidate Label:"<> "Line["<> ToString[n]<>"]" <>candidateNewSymbol<> "->"<> ToString[ramAddress]] ;*)
	AppendTo[updatedSymbols,{candidateNewSymbol,ramAddress}];
	(* Now, increment ramAddress by 1*)
	ramAddress++ ;
	]
	]
	]
	n++ ];
	updatedSymbols
]

(* Clean up all assembly statements by stripping away comments.*)
StripComment[str_]:=Module[
{
newString=""
},
If[StringContainsQ[str,"//"],
(*THEN*)
newString= StringTrim[First[StringSplit[str, "//"]]], 
(*ELSE*)
newString=StringTrim[str]];
newString
]


(* Given binary string represented Hack code, create its textual representation including end of line.*)
Translation[rawText_]:= Module[
{
arrayOfLines = {},
asmArray = {},
binaryCodeArray = {},
binaryCodeString=""
},
arrayOfLines= StringSplit[rawText, "\n"];
If[Length[arrayOfLines]<=0, 
(*Then*) Print["No Text to be translated"]; Return Null
];

asmArray=CollectInstruction[arrayOfLines];
(* Print[asmArray]; *)
binaryCodeArray=TranslateInstruction[asmArray];
(* Print[binaryCodeArray];*)
If[Length[binaryCodeArray]<=0, 
(*Then*) Print["No Code to be translated"],
(*Else*) binaryCodeString =StringJoin[Map[(#<>"\n")&, binaryCodeArray]]
];
binaryCodeString
];


(* Given binary string represented Hack code, create its textual representation including end of line.*)
TranslateHackCodeWithUpdatedSymbols[rawText_, initialSymbols_]:= 
	Module[
		{arrayOfLines, asmArray, binaryCodeArray, binaryCodeString, 
			rawTextualInstructions, instructionSetWithoutLineComments, 
			labelCollectionResult, updatedSymbols, symbolsWithRamAddress
		},

	arrayOfLines = {};
	asmArray = {};
	binaryCodeArray = {};
	binaryCodeString="";
	rawTextualInstructions={};
	instructionSetWithoutLineComments={};
	labelCollectionResult={};
	updatedSymbols={};
	symbolsWithRamAddress ={};

	arrayOfLines= StringSplit[rawText, "\n"];
	If[Length[arrayOfLines]<=0, 
	(*Then*) Print["No Text to be translated"]; Return Null
	];

	rawTextualInstructions=CollectInstruction[arrayOfLines];
	(* Print[rawTextualInstructions]; *)

	labelCollectionResult =CollectLabels[rawTextualInstructions,initialSymbols];
	updatedSymbols= labelCollectionResult[[1]];

	instructionSetWithoutLineComments=Map[StripComment,Delete[rawTextualInstructions, labelCollectionResult[[2]]]];

	symbolsWithRamAddress=CollectRamAddress[instructionSetWithoutLineComments, updatedSymbols];

	binaryCodeArray=TranslateInstructionWithUpdatedSymbols[instructionSetWithoutLineComments,
	symbolsWithRamAddress];
	(* Print[binaryCodeArray];*)
	If[Length[binaryCodeArray]<=0, 
	(*Then*) Print["No Code to be translated"],
	(*Else*) binaryCodeString =StringJoin[Map[(#<>"\n")&, binaryCodeArray]]
	];
	binaryCodeString
	];


End[ ]

EndPackage[ ]
