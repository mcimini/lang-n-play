open Batteries
open Option
open Aux
open Loml
open Declarations

let abslo = "absLO"
let applo = "appLO"
let letlo = "letLO"
let languagelo = "language"
let unionlo = "unionLO"
let removelo = "deleteLO"
let strategy = "strategy"
let checkStrategyPredicate = "check-strategy"

let iflo = "ifLO"
let truelo = "trueLO"
let falselo = "falseLO"
let letreclo = "letrecLO"
let conslo = "consLO"
let nillo = "nilLO"
let headlo = "headLO"
let taillo = "tailLO"

let rec apply_abstractions_term abstractions_map term = match term with 
	| Var(name) -> begin try Application(term, Constructor(List.assoc name abstractions_map, [])) with Not_found -> term end
	| Constructor(op, arguments) -> Constructor(op, List.map (apply_abstractions_term abstractions_map) arguments) 
	| Application(term1, term2) -> Application(apply_abstractions_term abstractions_map term1, apply_abstractions_term abstractions_map term2)
	| Abs(bindTag, term) -> Abs(bindTag, apply_abstractions_term abstractions_map term)
    | Switch(flag, e, term) -> Switch(flag, e, apply_abstractions_term abstractions_map term)
    | _ ->  raise(Failure("pattern_match failed in apply_abstractions_term: " ^ show_term term))

	
let rec apply_abstractions_map abstractions_map formula = match formula with 
| Formula(pred, args) -> Formula(pred, List.map (apply_abstractions_term abstractions_map) args)
| Generic(formula) -> apply_abstractions_map abstractions_map formula
					
(* This function below works only top level *)			
(* also some variables are lowercase such as e1 e2, v1 v2, so we search them also in constructors *)			
let formula_get_abstractions_map formula = 
	let rec create_map term = 
	begin match term with 
	| Var(name) -> []
	| Constructor(op, arguments) -> List.concat (List.map create_map arguments)
	| Application(term1, term2) -> []
	| Abs(bindTag, term1) -> List.map (fun var -> (var_to_string var,bindTag)) (term_getVariables term1) 
	end
	in match formula with Formula(pred, args) -> List.concat (List.map create_map args) 
	

let wrapParenthesis formulaString = "(" ^ formulaString ^ ")"
let wrapInQuantifier var = "pi " ^ var ^ "\\ "

let rec generateTerm term = match term with
         | Var(variable) -> variable
         | Constructor(name, arguments) -> if name = abslo then "(" ^ abslo ^ " " ^ generateTerm (Abs(var_to_string (List.hd arguments), List.hd (List.tl arguments))) ^ ")" 
   											else if name = letlo then "(" ^ letlo ^ " " ^ generateTerm (List.nth arguments 1) ^ " " ^ generateAbstraction [(List.nth arguments 0) ; (List.nth arguments 2)] ^ ")"
											else if name = letreclo then "(" ^ letreclo ^ " " ^ generateAbstraction [(List.nth arguments 0) ; (List.nth arguments 1)] ^ " " ^ generateAbstraction [(List.nth arguments 0) ; (List.nth arguments 2)] ^ ")"
										   else "(" ^ name ^ (if arguments = [] then "" else " ") ^ (String.concat " " (List.map generateTerm arguments)) ^ ")"
         | Application(term1, term2) -> generateTerm (Constructor(generateTerm term1, [term2]))
         | Abs(bind, term) -> if is_var term then generateTerm term else "(" ^ bind ^ "\\" ^ generateTerm term ^ ")"
         | Switch(flag, e, term) ->  let embedWithTreatmentForCopyOrInherit switchOperator n = 
							     		let argsInConf = List.mapi (toGenericVarByIndex "H") (repeat n n) in 
							     		 let expToTermToEmbed = compile (Exec(e, (wrap_in_configuration argsInConf term))) in 
								   	  		generateTerm (Constructor(switchOperator, [wrapbyAbstractions expToTermToEmbed argsInConf])) in 
					 						begin match flag with  (* notice, if the state is New it just prints the term without abstractions.. we make it happen also for the type checking pass *)
 					 						| NewState -> generateTerm (Constructor(switchInherit, [compile (Exec(e, term))])) 
											| CopyState n -> embedWithTreatmentForCopyOrInherit switchCopy n 
 											| InheritState n -> embedWithTreatmentForCopyOrInherit switchInherit n 
											end
		  | _ ->  raise(Failure("User program cannot be generated" ^ show_term term))
and generateAbstraction (var :: body :: rest) = "(" ^ generateTerm var ^ "\\ " ^ generateTerm body  ^ ")"
and compile exp = match exp with 
	| VarLO(var) -> Var(var) 
    | AbsLO(var, typ, e) -> Constructor(abslo, [Var(var) ; (compile e)]) 
    | AppLO(e1, e2) -> Constructor(applo, [(compile e1) ; (compile e2)]) 
    | LetLO(var, e1, e2) -> Constructor(letlo, [Var(var) ; (compile e1) ; (compile e2)]) 
    | Language(syntax, rules) -> Constructor(languagelo, (compile_rules rules)) 
    | Union(e1, e2)  -> Constructor(unionlo, [(compile e1) ; (compile e2)]) 
    | Exec(e, conf) ->  Constructor(execlo, [compile e ; conf])  (* (Union(e, steps_inside_configurations conf))  *)
    | VV -> Constructor(strategy, [Var("(x\\ value x)")]) 
    | EE -> Constructor(strategy, [Var("(x\\ true)")]) 
	| AbsLAN(var, e) -> compile e
	| AbsSTR(var, e) -> Constructor(abslo, [Var(var) ; (compile e)])   (* compile e *)
	| If (e1, e2, e3) -> Constructor(iflo, [(compile e1) ; (compile e2) ; (compile e3)])
	| TT -> Constructor(truelo, []) 
	| FF -> Constructor(falselo, []) 
	| NilLO -> Constructor(nillo, []) 
	| ConsLO(e1,e2) -> Constructor(conslo, [(compile e1) ; (compile e2)])
	| HeadLO(e) -> Constructor(headlo, [(compile e)])
	| TailLO(e) -> Constructor(taillo, [(compile e)])
    | LetrecLO(var, typ, e1, e2) -> Constructor(letreclo, [Var(var) ; (compile e1) ; (compile e2)]) 
    | Remove(r, e)  -> Constructor(removelo, compile_rules [r] @ [(compile e)]) 
    | _ ->  raise(Failure("Expression to be compiled: not recognized" ^ show_exp exp))
and compile_rules rules = [Var("[" ^ String.concat ", "  (List.map wrapParenthesis (List.map generateRuleQuantified rules)) ^ "]")]
and generateFormula formula = match formula with 
         | Formula(pred, arguments) -> pred ^ " " ^ (String.concat " " (List.map generateTerm arguments))
         | Generic(formula) -> "(pi x\\ " ^ generateFormula formula ^ ")"
and generatePremises abstractions_map premises = String.concat ", " (List.map (fun premise -> "(" ^ String.concat " " (List.map wrapInQuantifier (List.map snd abstractions_map)) ^ " " ^ (generateFormula premise) ^ ")") (List.map (apply_abstractions_map abstractions_map) premises))
and generateRuleNO_DOT rule = match rule with Rule(premises,conclusion) ->
 		let boundInTheWholeRule = list_difference (object_level_variables conclusion) ((List.map snd (formula_get_abstractions_map conclusion))) in 
	 	let variables = List.map generateTerm (removeDuplicates (rule_getAllVariables rule)) in 
         let pr = if premises = [] then " :- true" else " :- " ^ generatePremises (formula_get_abstractions_map conclusion) premises in 
           (String.concat " " (List.map wrapInQuantifier boundInTheWholeRule)) ^ " " ^ (generateFormula conclusion) ^ pr 
and generateRule rule = generateRuleNO_DOT rule ^ ".\n"
and generateRuleQuantified rule = 
	let variables = List.map generateTerm (rule_getAllVariables rule) in
	 String.concat " " (List.map wrapInQuantifier variables) ^ " " ^ generateRuleNO_DOT rule

 let subtyping_standard_rules = 
 [
 Rule([], 
     toSubtyping (Var "T") (Var "T")) ;
 Rule([toSubtyping (Var "T1") (Var "T2") ; toSubtyping (Var "T2") (Var "T3")], 
     toSubtyping (Var "T1") (Var "T3")) ;
(* This doesn't work when you added GammaLO. 
	 Rule([toType (Var "Gamma") (Var "E") (Var "T1") ; toSubtyping (Var "T1") (Var "T2")], 
     toType (Var "Gamma") (Var "E") (Var "T2")) ;	
*)
	 Rule([toTypeWithGammaLO (Var "Gamma") (Var "E") (Var "T1") ; toSubtyping (Var "T1") (Var "T2")], 
     toTypeWithGammaLO (Var "Gamma") (Var "E") (Var "T2")) ;	
 ]

let addSubtyping syntax rules = 
let searchResult = List.filter (fun rule -> conclusion_getPredicateName (rule_getConclusion rule) = declarativeSubtyping) rules in 
if searchResult = [] then [] else 
 let varianceDeclarations = conclusion_getArguments (rule_getConclusion (List.hd searchResult)) in 
  let typeDeclarations = try snd (List.assoc "Type" syntax) with Not_found -> raise(Failure("The language has been declared up-to subtyping but it has no types")) in 
   let obtainSubtypingRule term = (match term with 
		| Constructor(name, []) -> [Rule([],toSubtyping term term)] 
			| Constructor(name, args) -> let argumentVariables = List.mapi (toGenericVarByIndex "T") args in 
										let toTickIfNotInvariant (i : int) var = if type_is_role varianceDeclarations invariant name (i+1) then var else tick var in 
										let conclusion = Formula(subtyping, [Constructor(name, argumentVariables) ; Constructor(name, List.mapi toTickIfNotInvariant argumentVariables)]) in 
										let subtypingPremise (i : int) var = if type_is_role varianceDeclarations contravariant name (i+1) then toSubtyping (tick var) var else if type_is_role varianceDeclarations invariant name (i+1) then toSubtyping var var else toSubtyping var (tick var) in 
										let premises = List.mapi subtypingPremise argumentVariables in 
											[Rule(premises, conclusion)]
		| _ -> raise(Failure("In addSubtyping, found out that a type is not of the form (op .. )"))) in 
	    let _ = print_string ("before:" ^ show_exp (Language(syntax, rules))) in
	    let _ = print_string (String.concat "\n" (List.map show_term typeDeclarations)) in
	List.concat (List.map obtainSubtypingRule typeDeclarations) @ subtyping_standard_rules  (* Here concat just because some types do no need a subtying rule so I return [] *)
	
let rec compile_values_and_ctxs vars exp = match exp with 
	| VarLO(var) -> VarLO(var)
    | AbsLO(var, typ, e) -> AbsLO(var, typ, compile_values_and_ctxs (Var(var) :: vars) e)
    | AppLO(e1, e2) -> AppLO(compile_values_and_ctxs vars e1, compile_values_and_ctxs vars e2)
    | LetLO(var, e1, e2) -> LetLO(var, compile_values_and_ctxs (Var(var) :: vars) e1, compile_values_and_ctxs (Var(var) :: vars) e2)
    | Language(syntax, rules) -> Language(syntax, List.map (compile_values_and_ctxs_by_rules vars) rules @ List.map (compile_values_and_ctxs_by_rules vars) (compile_values_and_ctxs_by_syntax syntax))
    | Union(e1, e2)  -> Union(compile_values_and_ctxs vars e1, compile_values_and_ctxs vars e2)
    | Exec(e, conf) ->  Exec(compile_values_and_ctxs vars e, conf)
    | VV -> VV
    | EE -> EE
	| AbsLAN(var, e) ->  AbsLAN(var, compile_values_and_ctxs (Var(var) :: vars) e)
	| AbsSTR(var, e) ->  AbsSTR(var, compile_values_and_ctxs (Var(var) :: vars) e)
	| If (e1, e2, e3) -> If (compile_values_and_ctxs vars e1, compile_values_and_ctxs vars e2, compile_values_and_ctxs vars e3) 
	| TT -> TT
	| FF -> FF
	| NilLO -> NilLO
	| ConsLO(e1,e2) -> ConsLO(compile_values_and_ctxs vars e1, compile_values_and_ctxs vars e2)
	| HeadLO(e) -> HeadLO(compile_values_and_ctxs vars e)
	| TailLO(e) -> TailLO(compile_values_and_ctxs vars e)
    | LetrecLO(var, typ, e1, e2) -> LetrecLO(var, typ, compile_values_and_ctxs (Var(var) :: vars) e1, compile_values_and_ctxs (Var(var) :: vars) e2)
    | Remove(r, e) -> Remove(compile_values_and_ctxs_by_rules vars r, compile_values_and_ctxs vars e)
	| _ ->  raise(Failure("Expression to compile, not an expression: " ^ show_exp exp))
	and compile_values_and_ctxs_by_rules vars rule = 
		let rule = add_abstracting_if_found_abstraction rule in 
		let valuehood_or_abstracted_valuehood v = if List.mem (var_uncapitalize v) vars then Formula(checkStrategyPredicate, [Constructor(generateTerm (var_uncapitalize v), []) ; v]) else toValue v in (* Application(Var (String.uncapitalize (generateTerm v)), v) *)
		  rule_addPremises rule (List.map valuehood_or_abstracted_valuehood (List.filter var_is_value (rule_getAllVariables rule))) 
  and compile_values_and_ctxs_by_syntax syntax = 
		let valueDeclarations = try Some (snd (List.assoc "Value" syntax)) with Not_found -> None in (* Value declarations may miss if programmer passes just a piece of the language *)
		let errorDeclarations = try Some (snd (List.assoc "Error" syntax)) with Not_found -> None in 
		let contextDeclarations = try Some (snd (List.assoc "Context" syntax)) with Not_found -> None in 
		let configurationDeclaration = try Some (snd (List.assoc "Configuration" syntax)) with Not_found -> None in 
		  (if is_some valueDeclarations then List.map (declarationToRule toValue) (get valueDeclarations) else []) @
		  (if is_some errorDeclarations then List.map (declarationToRule toError) (get errorDeclarations) else []) @
		  (if is_some contextDeclarations then List.map (contextDeclarationToRules configurationDeclaration) (get contextDeclarations) else []) @
		  (if is_some configurationDeclaration then addRuleToSwitchLanguage (get configurationDeclaration) else simpleRuleToSwitch) (* This call will also place the declaration for understanding when a whole configuration should be considered a result/value  *)

	
let compile_ exp = compile (compile_values_and_ctxs [] exp)

let rec typeLO_to_termELPI typ = match typ with 
	| TLanguage(syntax, rules, constraints) -> Constructor("tlanguage", (compile_rules rules))
	| TArrow(typ1,typ2) -> Constructor("arrowLO", [typeLO_to_termELPI typ1 ; typeLO_to_termELPI typ2])
	| TStrategy -> Constructor("tstrategyLO", [])
	| other -> Constructor("notAllowedType", [])

(* let test = printQuery firstProgram;; *)
