open Batteries
open Option
open Aux
open Loml
open Equality
open TypeCheckerConfiguration
open Compiler

let get_terms_if_same_grammarVar grammarVar1 (grammarVar2, terms) = if grammarVar1 = grammarVar2 then terms else type_error ("In union of languages, there are different grammar variables for a same syntactic category")
let syntactic_category_add_one syntax (category, (grammarVar, terms)) = begin try (category, (grammarVar, get_terms_if_same_grammarVar grammarVar (List.assoc category syntax) @ terms)) :: (List.remove_assoc category syntax) with | _ -> (category, (grammarVar, terms)) :: syntax end 
let syntactic_category_union syntax1 syntax2 = List.fold_left syntactic_category_add_one syntax1 syntax2 

(* The second language must be fully determined 
   This may mean that a language fragment with a variable cannot be passed to another language application. 
*)
let language_type_union (TLanguage(syntax1, rules1, varAndConstraints1)) (TLanguage(syntax2, rules2, None)) = 
		TLanguage(syntactic_category_union syntax1 syntax2, rules1 @ rules2, varAndConstraints1)

let remove_language_variable (TLanguage(syntax, rules, varAndConstraints)) = (TLanguage(syntax, rules, None))

let rec query_check delta syntax rules query = match query with 
	| Absence(operatorname) -> not (List.exists (fun (category, (grammarVar, terms)) -> List.exists (fun term -> term_getOperator term = operatorname) terms) syntax)
	| AbsenceSyntax((category, (grammarVar, terms))) -> not (begin try (let (grammarVar2, terms2) = List.assoc category syntax in grammarVar = grammarVar2 && list_subset terms2 terms) with | _ -> false end)
	| AbsenceRule(rule) -> not (List.mem rule rules)

let rec language_fragment_add typToSubst var typToChange = 
	begin match typToChange with 
	| TLanguage(syntax, rules, varAndConstraints) -> if is_none varAndConstraints then typToChange else let (languageVar, constraints) = get varAndConstraints in if languageVar = var then remove_language_variable (language_type_union typToChange typToSubst) else typToChange 
	| TArrow(t1, t2) -> TArrow(language_fragment_add typToSubst var t1, language_fragment_add typToSubst var t2) 
	| TStrategy -> typToChange
	| InType(t) -> typToChange
	| LAMBDA(var2, typ) -> LAMBDA(var2, language_fragment_add typToSubst var typ)
	end

let type_is_strategy typ = match typ with 
| TStrategyVV -> true
| TStrategyEE -> true
| _ -> false

	
let rule_apply_strategy typToSubst var rule = 
	if typToSubst = TStrategyEE then match rule with Rule(premises, conclusion) -> Rule(List.map (formula_substitute (Var ("EE" ^ var)) var) premises, formula_substitute (Var ("EE" ^ var)) var conclusion) 
	else if List.mem (Var (String.capitalize var)) (rule_getAllVariables rule) then rule_addPremises rule [toValue (Var (String.capitalize var))] else rule 
	
let rec type_apply_strategy typToSubst var typToChange = 
	begin match typToChange with 
	| TLanguage(syntax, rules, varAndConstraints) -> TLanguage(syntax, List.map (rule_apply_strategy typToSubst var) rules, varAndConstraints)
	| TArrow(t1, t2) -> TArrow(type_apply_strategy typToSubst var t1, type_apply_strategy typToSubst var t2) 
	| TStrategyVV -> typToChange
	| TStrategyEE -> typToChange
	| InType(t) -> typToChange
	| LAMBDA(var2, typ) -> LAMBDA(var2, type_apply_strategy typToSubst var typ)
	| LambdaSTR(var2, typ) -> LambdaSTR(var2, type_apply_strategy typToSubst var typ)
	end

	(* this doesn't seem right *)
let rec well_formed_type delta typ = 
	begin match typ with 
	| TLanguage(syntax, rules, None) -> true 
	| TLanguage(syntax, rules, (Some(varAndConstraints))) -> if List.mem_assoc (fst varAndConstraints) delta then true else type_error ("A Language fragment uses a variable that is not bound")
	| TArrow(t1, t2) -> well_formed_type delta t1 && well_formed_type delta t2
	| TStrategy -> true
	| TBool -> true
	| InType(t) -> true
	| LAMBDA(var, typ2) -> well_formed_type ((var, []) :: delta) typ2
	| LambdaSTR(var, typ2) -> well_formed_type ((var, []) :: delta) typ2
end

type type_environment = (varname * typ) list
type  query_environment= (languageVar * (language_constraint list)) list

(* type checker also returns language resolved for nexted exec *)
(* flag is true when you also need to insert explicit languages, which is the first step *)
let rec type_checker flag (delta : query_environment) (gamma : type_environment) exp = match exp with 
	| VarLO(var) -> begin try (List.assoc var gamma, exp) with | _ -> (type_error ("variable " ^ var ^ " is not declared")) end
	| AbsLO(var, typ, e) -> let _ = well_formed_type delta typ in 
								let (typ2, e') = type_checker flag ((var, []) :: delta)  ((var, typ) :: gamma) e in (TArrow(typ, typ2), AbsLO(var, typ, e'))
	| AppLO(e1, e2) -> let (t1, e1') = type_checker flag delta gamma e1 in 
						let (t2, e2') = type_checker flag delta gamma e2 in
						begin match t1 with 
							| TArrow(t11, t12) -> if equality t2 t11 then (t12, AppLO(e1', e2')) else type_error ("In application, in argument position: the expression is not of the type of the domain of the function" ^ generateTerm (typeLO_to_termELPI t2) ^ "--" ^ generateTerm (typeLO_to_termELPI t11))
							| LAMBDA(var, typ) -> (fst (type_checker flag delta gamma (AppLO((AppLAN(e1, t2)), e2))), AppLO(e1', e2')) (* just the type from AppLo, which is the fst *)
							| LambdaSTR(var, typ) -> if type_is_strategy t2 then (type_apply_strategy t2 (String.capitalize var) typ, AppLO(e1', e2')) else type_error ("In application, in argument position: the expression is not a strategy.")
							| _ -> type_error ("In application, function position: the expression is not a function")
					    end
	| LetLO(var, e1, e2) -> let (typ, e1') = type_checker flag ((var, []) :: delta) gamma e1 in 
							 let (typ2, e2') = type_checker flag ((var, []) :: delta)  ((var, typ) :: gamma) e2 in 
							   (typ2, LetLO(var, e1', e2'))
	| Language(syntax, rules) -> (TLanguage(syntax, rules, None), Language(syntax, rules))
	| Union(e1, e2)  -> let (typ1, e1') = type_checker flag delta gamma e1 in begin match typ1 with 
							| (TLanguage(syntax1, rules1, varAndConstraints)) -> let (typ2, e2') = type_checker flag delta gamma e2 in begin match typ2 with 
															| (TLanguage(syntax2, rules2, None)) -> (language_type_union typ1 typ2, Union(e1', e2'))
															| _ -> type_error ("In union of languages, second argument: the expression is not a language or is not a determined language")
															end
							| _ -> type_error ("In union of languages, first argument: the expression is not a language")
						end
	| Exec(e, conf) -> let (t, e') = type_checker flag delta gamma e in begin match t with 
							| TLanguage(syntax, rules, varAndConstraints) -> 
								match flag with 
								| 0 -> let number = let configDecl = syntax_getConfiguration syntax in if is_none configDecl then 0 else List.length (term_getArguments (get configDecl)) in 
											( InType(Var ""), Exec(e', insertInheritTag number gamma conf))
								| 1 -> let number = let configDecl = syntax_getConfiguration syntax in if is_none configDecl then 0 else List.length (term_getArguments (get configDecl)) in 
											( InType(Var ""), Exec(e', expand_languages number gamma conf))
								| 2	-> (InType(type_checking_configuration gamma syntax rules conf), VarLO("")) (* the second element of the pair is just a dummy when flag is false *)
							| _ -> type_error ("In exec, in language position: the expression is not a language")
						end
	| VV -> (TStrategyVV, VV)
	| EE -> (TStrategyEE, EE)
	| AbsLAN(var, e) -> if List.mem_assoc var delta then type_error ("In language fragment abstraction, language fragment variable is already used.") 
								else let (t, e') = type_checker flag ((var, []) :: delta) gamma e in (LAMBDA(var, t), AbsLAN(var, e'))
	| AppLAN(e, typ1) -> begin match typ1 with 
							| TLanguage(syntax, rules, varAndConstraints) -> let _ = well_formed_type delta typ1 in 
								let (typOfe, e') = type_checker flag delta gamma e in begin match typOfe with 
							       | LAMBDA(var, typ2) -> (language_fragment_add typ1 var typ2, AppLAN(e', typ1)) (* typToSubst var typToChange *)
							       | _ -> type_error ("In language fragment application, the first argument is not an abstraction")
								  end
						    | _ -> type_error ("In language fragment application, the argument being passed is not a language fragment")
						end
	| AbsSTR(var, e) -> let (t, e') = type_checker flag ((var, []) :: delta) gamma e in (LambdaSTR(var, t), AbsSTR(var, e'))
	| TT -> (TBool, TT)
	| FF -> (TBool, FF)
	| If(e1,e2,e3) -> let (t1, e1') = type_checker flag delta gamma e1 in 
						if not (t1 = TBool) 
							then type_error ("If expression, the condition is not a boolean")
							else let (t2, e2') = type_checker flag delta gamma e2 in 
									let (t3, e3') = type_checker flag delta gamma e3 in
									if true (* equality t2 t3 *)
										then (t2, If(e1',e2',e3'))
										else type_error ("If expression, types of the two branches do not match: " ^ show_typ t2 ^ " and " ^ show_typ t3)
	| ConsLO(e1,e2) -> let (t1, e1') = type_checker flag delta gamma e1 in 
										if e2 = NilLO 	
											then (TList(t1), ConsLO(e1',NilLO))
											else let (TList(t2), e2') = type_checker flag delta gamma e2 in 
											if equality t1 t2 
												then (TList(t1), ConsLO(e1',e2'))
												else type_error ("In list, elements are of different types")
	| HeadLO(e) -> let (tlist, e') = type_checker flag delta gamma e in 
										begin match tlist with 
										| TList(t) -> (t, HeadLO(e')) 
										| _ -> type_error ("Head of list operation is applied to an expression that is not a list") 
										end
	| TailLO(e) -> let (tlist, e') = type_checker flag delta gamma e in 
										begin match tlist with 
										| TList(t) -> (tlist, TailLO(e')) 
										| _ -> type_error ("Head of list operation is applied to an expression that is not a list") 
										end
	| LetrecLO(var, typVar, e1, e2) -> let (typ, e1') = type_checker flag ((var, []) :: delta)  ((var, typVar) :: gamma) e1 in
										if equality typ typVar 
											then let (typ2, e2') = type_checker flag ((var, []) :: delta)  ((var, typVar) :: gamma) e2 in (typ2, LetrecLO(var, typVar, e1', e2'))
											else type_error ("In letrec, the expression that binds the variable is not of the same type of the variable")
	| Remove(r,e) -> let (typ, e') = type_checker flag delta gamma e in begin match typ with 
							| (TLanguage(syntax1, rules1, varAndConstraints)) -> ((TLanguage(syntax1, list_difference rules1 [r], varAndConstraints)), Remove(r,e'))
							| _ -> type_error ("In remove of languages, the expression is not a language")
							end
	| _ -> type_error ("None of the exp matched for a case")
and expand_languages number gamma conf = 
	match conf with 
	| Var(name) -> Var(name)
	| Constructor(op, arguments) -> Constructor(op, List.map (expand_languages number gamma) arguments)
	| Application(term1, term2) -> Application(expand_languages number gamma term1, expand_languages number gamma term2)
	| Abs(bindTag, term) -> Abs(bindTag, expand_languages number gamma term)
	| Switch(n, e, term) -> let (t, e') = type_checker 1 [] gamma e in (* flag is 1 because you need to insert explicit languages *)
							begin match t with 
							| TLanguage(syntax, rules, varAndConstraints) -> 
							(*	let _ = print_string ("I have tranformed : " ^ generateTerm (Switch(n, e, term)) ^ "into : " ^ generateTerm (Switch(n, Language([], rules), type_checker_configuration gamma term))); in *) 
							(*	Notice that the flag is set to NewState, so that the pass for calling Elpi for type checking is done with generateTerm that detects that 
							    it does not have to print abstractions to pass the configuration state around, which serves only at run-time, for type-checking you'd use generateTerm at some point but it must skip the abstractions *) 
								(Switch(InheritState(number), Language([], rules), expand_languages number gamma term))
							| _ -> type_error ("In nested exec, in language position: the expression is not a language")
							end
and insertInheritTag number gamma conf = 						
match conf with 
	| Var(name) -> Var(name)
	| Constructor(op, arguments) -> Constructor(op, List.map (insertInheritTag number gamma) arguments)
	| Application(term1, term2) -> Application(insertInheritTag number gamma term1, insertInheritTag number gamma term2)
	| Abs(bindTag, term) -> Abs(bindTag, expand_languages number gamma term)
	| Switch(n, e, term) -> let (t, e') = type_checker 0 [] gamma e in (* flag is 0 because you need to insert inherit tags *)
							Switch(InheritState(number), e', insertInheritTag number gamma term)  



						(* type_error ("here typToSubst: " ^ show_typ typ1 ^ "here var: " ^ var ^ "here typToChange: " ^ show_typ typ2 ^ "and union = " ^ show_typ (						
						else type_error ("In let, the expression is not of the type specified.: " ^ (show_typ typ) ^ "--" ^ (show_typ (type_checker delta ((var, typ) :: gamma) e1)) ^ "--" ^ (show_typ (type_checker delta ((var, typ) :: gamma) e2)) ^ "--" ^ string_of_bool (equality typ (type_checker delta ((var, typ) :: gamma) e1))) *)