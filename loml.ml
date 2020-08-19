open Batteries
open Option
open Aux

let typing = "typeOf"
let errorPred = "error"
let valuePred = "value"
let step = "step"
let typeKind = "typ"
let termKind = "term"
let equality = "equal"
let subtyping = "subtype"
let member = "mem"
let colon = "colon"
let cons = "cons"
let nil = "nil"
let declarativeSubtyping = "declarativeSubtyping"
let contravariant = "contravariant"
let invariant = "invariant"

let configuration = "conf"
let switchNew = "switchNew"
let switchCopy = "switchCopy"
let switchInherit = "switchInherit"
let execlo = "exec"
let extract_state = "extract_state"
let extract_program = "extract_program"
let extensionFiles = ".lop"

let typecheckerLO = "typeOfLO"

let language_implementation = "lib/loml.elpi"
let language_implementationWithPrePost = "lib/lomlPreAndPost.elpi"

let elpi_init : (Elpi_API.Setup.program_header option) ref = ref None
let lomlImplementation : (Elpi_API.Ast.program option) ref = ref None
let prepost = ref false

type operatorname = string [@@deriving show, eq]
type varname = string [@@deriving show, eq]
type grammarCategoryName = string [@@deriving show, eq]
type grammarVariable= string [@@deriving show, eq]
type predicatename = string [@@deriving show, eq]
type bindingTag = string [@@deriving show, eq]


type flag = 
  | NewState 
  | CopyState of int
  | InheritState of int
  [@@deriving show, eq]

type term =
  | Var of varname
  | Constructor of operatorname  * term  list 
  | Application of term  * term  
  | Abs of bindingTag  * term  
  | Switch of flag * exp  * term 
  | SwitchPrePost of flag * exp * varname * varname * term 
  [@@deriving show, eq]
and formula =
  | Formula of predicatename * term list 
  | Hypothetical of formula * formula
  | Generic of formula
  [@@deriving show, eq]
and rule = Rule of formula list * formula [@@deriving show, eq]
and syntactic_category = (grammarCategoryName * (grammarVariable * (term list)))  [@@deriving show, eq]
and exp =
  | VarLO of varname
  | AbsLO of varname * typ * exp  
  | AppLO of exp  * exp  
  | LetLO of varname * exp  * exp  
  | Language of (syntactic_category list) * (rule list)
  | Union of exp  * exp 
  | Exec of exp  * term 
  | ExecPrePost of exp * varname * varname * term 
  | VV 
  | EE 
  | Int of int  
  | If of exp  * exp  * exp    
  | TT 
  | FF 
  | Import of string 
  | AbsLAN of languageVar * exp
  | AppLAN of exp  * typ 
  | AbsSTR of varname * exp
  | LetrecLO of varname * typ * exp  * exp  
  | NilLO 
  | ConsLO of exp * exp  
  | HeadLO of exp
  | TailLO of exp
  | Remove of rule  * exp 
  [@@deriving show, eq]
and typ = 
  | TLanguage  of (syntactic_category list) * (rule list) * ((languageVar * (language_constraint list)) option) 
  | TArrow of typ * typ 
  | TStrategy 
  | TStrategyVV 
  | TStrategyEE 
  | InType of term
  | LAMBDA of languageVar * typ
  | LambdaSTR of varname * typ
  | TVar of languageVar 
  | TInt
  | TBool 
  | TList of typ
  [@@deriving show, eq]
and languageVar = string [@@deriving show, eq]
and language_constraint = 
    | Absence of operatorname
    | AbsenceSyntax of syntactic_category
    | AbsenceRule of rule
    [@@deriving show, eq]

let toValueLO term = Formula("valueLO", [term])
let toErrorLO term = Formula("errorLO", [term])
let toException term = Formula("exceptionLO", [term])
let toStepLO source target = Formula("stepLO", [source ; target])
let toNStepLO source target = Formula("nstepLO", [source ; target])
let toStuck source target = Formula("stuck", [source ; target])
let toMain term = Formula("main", [term])

let toValue term = Formula("value", [term])
let toError term = Formula("error", [term])
let toStep term1 term2 = Formula("step", [term1 ; term2])
let toSubtyping term1 term2 = Formula(subtyping, [term1 ; term2])
let toType term1 term2 term3 = Formula(typing, [term1 ; term2 ; term3])
let toTypeWithGammaLO term1 term2 term3 = Formula(typing, [Var("GammaLO") ; term1 ; term2 ; term3])
let set_Ith_as_value i = toValue (Var("E" ^ string_of_int i))

let var_capitalize (Var(varname))= Var(String.capitalize varname) 
let var_uncapitalize (Var(varname))= Var(String.uncapitalize varname) 

let boundVar =  Constructor("x", [])
let switchTerm term = Constructor(switchInherit, [term])

let tick var = match var with Var(varname) -> Var(varname ^ "'") | _ -> raise(Failure ("tick")) 
let tickIfInIndex indexes i var = if List.mem (i+1) indexes then tick var else var 

let formula_true = Formula("true", [])
let detect_var_or_op op = if (String.starts_with op "v" || String.starts_with op "e") && (is_numeric (String.lchop op) || (String.lchop op) = "") then Var(String.capitalize op) else Constructor(op, [])
let var_is_value (Var var) = String.starts_with var "V"
let is_var var = match var with Var(_) -> true | _ -> false
let is_abstraction term = match term with Abs(_,_) -> true | _ -> false
let toVarByIndex varname i =  Var(varname ^ string_of_int i)
let toGenericVarByIndex varname i arg = Var(varname ^ string_of_int i)
let var_to_string (Var var) = var
let language_variable typ = match typ with | TVar(var) -> true | _ -> false

let language_getSyntax (Language(syntax, rules)) = syntax
let language_getRules (Language(syntax, rules)) = rules

let wrap_in_configuration argsOfConf term = Constructor(configuration, term :: argsOfConf)
let wrap_in_exec terms = Constructor(execlo, terms)
let wrap_in_configuration_formula argsInConf formula = match formula with 
	| Formula(pred, [term1 ; term2]) -> Formula(pred, [wrap_in_configuration argsInConf term1 ; wrap_in_configuration (List.map tick argsInConf) term2])
	| otherwise -> raise(Failure ("wrap_in_configuration_formula is not called with a step formula term1 --> term2")) 
let wrap_in_configuration_formula_no_tick argsInConf formula = match formula with 
	| Formula(pred, [term1 ; term2]) -> Formula(pred, [wrap_in_configuration argsInConf term1 ; wrap_in_configuration argsInConf term2])
	| otherwise -> raise(Failure ("wrap_in_configuration_formula is not called with a step formula term1 --> term2")) 

let rec wrapbyAbstractions term variables = match variables with 
	| [] -> term
	| (var :: rest) -> Abs(var_to_string var, wrapbyAbstractions term rest)

let rec foldbyApplications terms = match terms with 
	| [] -> raise(Failure ("term_getOperator")) 
	| (t1 :: t2 :: rest) -> if rest = [] then Application(t1, t2) else foldbyApplications (Application(t1, t2) :: rest)

let rec makeAbstraction args e = if args = [] then e else let (var, typ) = List.hd args in if language_variable typ then AbsLAN(var, (makeAbstraction (List.tl args) e)) else if typ = TStrategy then AbsSTR(var, (makeAbstraction (List.tl args) e)) else AbsLO(var, typ, (makeAbstraction (List.tl args) e))
let rec makeCons elements = if elements = [] then NilLO else let first = List.hd elements in ConsLO(first, makeCons (List.tl elements))
let list_last = List.last (* to use List.last in parser.mly. Unfortunately "open Batteries" messes up there.  *)
let option_to_list ruleList = if is_none ruleList then [] else get ruleList
let option_to_flag flag = if is_none flag then InheritState(0) else get flag
let option_to_number n = if is_none n then 0 else get n
	
let term_getOperator term = match term with Constructor(op, args) -> op | otherwise -> raise(Failure ("term_getOperator")) 
let term_getArguments term = match term with Constructor(op, args) -> args | otherwise -> raise(Failure ("term_getArguments")) 

let rule_getConclusion rule = match rule with Rule(premises, conclusion) -> conclusion
let rule_getPremises rule = match rule with Rule(premises, conclusion) -> premises
let rule_addPremises rule premises1 = match rule with Rule(premises2, conclusion) -> Rule(removeDuplicates(premises2 @ premises1), conclusion)


let rec term_getVariables term = removeDuplicates (match term with 
| Var(name) -> [Var(name)]
| Constructor(op, arguments) -> List.concat (List.map term_getVariables arguments)
| Application(term1, term2) -> term_getVariables term1 @ term_getVariables term2
| Abs(bindTag, term) -> term_getVariables term
| Switch(n, e, term) -> [])

let conclusion_getPredicateName formula = match formula with Formula(pred, args) -> pred
let conclusion_getArguments formula = match formula with Formula(pred, args) -> args

let rec formula_getAllVariables premise = removeDuplicates (match premise with 
	| Formula(pred, args) -> List.concat (List.map term_getVariables args)
	| Generic(formula) -> formula_getAllVariables formula)

let rule_getAllVariables rule = removeDuplicates (List.concat (List.map formula_getAllVariables (rule_getPremises rule)) @ formula_getAllVariables (rule_getConclusion rule))

let rec term_getAbstracted term = match term with 
| Var(name) -> []
| Constructor(op, arguments) -> List.concat (List.map term_getAbstracted arguments)
| Application(term1, term2) -> term_getAbstracted term1 @ term_getAbstracted term2
| Abs(bindTag, term) -> term_getVariables term

let rec formula_getAbstracted premise = match premise with 
	| Formula(pred, args) -> List.concat (List.map term_getAbstracted args)


let formula_to_term formula = match formula with Formula(pred, args) -> Constructor("formula", [Constructor(pred, args)]) 
let term_to_formula term = match term with Constructor(pred, args) -> Formula(pred, args) 

let rec term_give_abstracting listOfAbstracted term = match term with 
| Var(name) -> if List.mem (Var(name)) listOfAbstracted then Application(Var(name), boundVar) else Var(name)
| Constructor(op, arguments) -> Constructor(op, List.map (term_give_abstracting listOfAbstracted) arguments)
	
let rec formula_give_abstracting listOfAbstracted formula = match formula with 
| Formula(pred, args) -> if listOfAbstracted = [] then Formula(pred, args) else Generic(Formula(pred, List.map (term_give_abstracting listOfAbstracted) args))
| Generic(formula) -> formula_give_abstracting listOfAbstracted formula

let add_abstracting_if_found_abstraction (Rule(premises, conclusion)) = let listOfAbstracted = formula_getAbstracted conclusion in Rule(List.map (formula_give_abstracting listOfAbstracted) premises, conclusion)

let fromLanToConstraints exp = 
	if is_none exp then [] else let exp = get exp in 
	begin match exp with 
		| Language(syntax, rules) -> (List.map (fun syntactic_category -> AbsenceSyntax(syntactic_category)) syntax) @ (List.map (fun rule -> AbsenceRule(rule)) rules)
		| _ -> raise(Failure("Negative constraints must be defined with the syntax for languages.")) 
	end
let toConstraints myvar lanToRemove = if is_some myvar then Some (get myvar, fromLanToConstraints lanToRemove) else None 


let equality_syntax syntax1 syntax2 = true
let equality_query syntax1 syntax2 = true

let rec equality typ1 typ2 = match (typ1, typ2) with 
	| (TLanguage(syntax1, rules1, languageVar1), TLanguage(syntax2, rules2, languageVar2)) -> equality_syntax syntax1 syntax2 && (list_subset rules1 rules2 && list_subset rules2 rules1) 
	| (TArrow(t11, t12), TArrow(t21, t22)) -> equality t11 t12 && equality t21 t22
	| (TStrategy, TStrategy) -> true
	| (InType(t1), InType(t2)) -> t1 = t2
	| (LAMBDA(var1, typ1), LAMBDA(var2,typ2)) -> var1 = var2 && equality typ1 typ2
	| _ -> false

let type_is_role varianceDeclarations role name i = List.exists (fun [Var(op) ; Var(n)] -> (op = name && i = int_of_string n)) (List.map term_getArguments (List.filter (fun term -> term_getOperator term = role) varianceDeclarations))

let rule_add_valuehood rule = let valuehoodPremises =  List.map toValue (removeDuplicates (List.filter var_is_value (rule_getAllVariables rule))) in rule_addPremises rule valuehoodPremises

let rec term_substitute typToSubst var term = match term with 
	| Var(name) -> if name = var then typToSubst else Var(name)
	| Constructor(op, arguments) -> Constructor(op, List.map (term_substitute typToSubst var) arguments)
	| Application(term1, term2) -> Application(term_substitute typToSubst var term1, term_substitute typToSubst var term2)
	| Abs(bindTag, term) -> Abs(bindTag, term_substitute typToSubst var term)

let rec formula_substitute typToSubst var formula = match formula with 
| Formula(pred, args) -> Formula(pred, List.map (term_substitute typToSubst var) args)
| Generic(formula) -> formula_substitute typToSubst var formula


let embedInSwitch formulaList = 
	let embedInSwitch_ formula = Switch(InheritState(2), Language([],[Rule([], formula)]), Var("")) in 
	List.map embedInSwitch_ formulaList

let object_level_variables formula = 
	let toEachArg arg = try (term_getOperator arg) = "x" with _ -> false in
	match formula with Formula(pred, args) -> List.map term_getOperator (List.filter toEachArg args)

let reservedNameThatShouldNotTurnIntoVariables name = match name with 
	| "empty" -> true
	| _ -> false

let turnGrammarNamesToVariables term = match term with 
	| Constructor(name, []) -> if reservedNameThatShouldNotTurnIntoVariables name then term else Var(String.capitalize name)
	| _ -> term

let syntax_getConfiguration syntax = try Some (List.hd (snd (List.assoc "Configuration" syntax))) with Not_found -> None 

let rec mute_switchInherit term = match term with 
	| Var(name) -> term
	| Constructor(op, arguments) -> Constructor(op, List.map mute_switchInherit arguments)
	| Application(term1, term2) -> Application(mute_switchInherit term1, mute_switchInherit term2)
	| Abs(bindTag, term) -> Abs(bindTag, mute_switchInherit term)
	| Switch(n, e, term) -> Switch(NewState, e, mute_switchInherit term)
	| SwitchPrePost(n, e, pre, post, term) -> Switch(NewState, e, mute_switchInherit term)
(*	| SwitchPrePost(n, e, pre, post, term) -> SwitchPrePost(NewState, e, pre, post, mute_switchInherit term) *)


	(*@ 
		
		begin try Application(term, Constructor(List.assoc op abstractions_map, [])) with Not_found -> 
			(begin match term1 with 
					| Constructor(op, arguments) -> if Var(op) = detect_var_or_op op then [] else [(op ,bindTag)] (*  *)
					| _ -> []
			 end)
*)
	