open Batteries
open Option
open Aux
open Loml

let valueOccurrence = Var("V")
let contextOccurrence = Var("C")

let turnConfigDeclarationToTerm (Constructor(op, args)) = Constructor(configuration, Var "E" :: args)

let turnDeclToConclusion op args = 
	let argAti i arg = let nameOfvar = if (is_var arg || is_abstraction arg) then "E" else term_getOperator arg in var_capitalize (Var(nameOfvar ^ string_of_int (i+1))) in  Constructor(op, List.mapi argAti args)

let declarationToRule toWhat decl = match decl with 
	| Constructor(op, args) -> let indexes = findIndicesByPred (fun arg -> arg = valueOccurrence) args in Rule(removeDuplicates (List.map set_Ith_as_value indexes), toWhat (turnDeclToConclusion op args))
	| _ -> raise(Failure("Declaration is not in the typical form: "))
let contextDeclarationToRules configurationDeclaration decl = 
	let configurationDeclaration = if is_none configurationDeclaration then [Constructor("e", [])] else (get configurationDeclaration) in 
	let configurationDeclaration = List.hd configurationDeclaration in  
	let argsInConf = List.mapi (toGenericVarByIndex "H") (term_getArguments configurationDeclaration) in 
		match decl with 
		| Constructor(op, args) -> let indexesContexts = findIndicesByPred (fun arg -> arg = contextOccurrence) args in 
								   let valuePremises = rule_getPremises (declarationToRule toValue decl) in 
								   let stepVars = (List.map (toVarByIndex "E") indexesContexts) in 
								   let stepPremises = List.map (wrap_in_configuration_formula argsInConf) (List.map (fun var -> toStep var (tick var)) stepVars) in 
								   let Constructor(source_op, source_args) = (turnDeclToConclusion op args) in 
								     Rule(valuePremises @ stepPremises, wrap_in_configuration_formula argsInConf (toStep (Constructor(source_op, source_args)) (Constructor(source_op, List.mapi (tickIfInIndex indexesContexts) source_args))))
		| _ -> raise(Failure("Declaration is not in the typical form: "))

let simpleRuleToSwitch = [Rule(
						[toStepLO (Var "E") (Var "E'")],
						toStep (Constructor(configuration, [(Constructor(switchInherit, [Var("E")]))])) (Constructor(configuration, [(Constructor(switchInherit, [Var("E'")]))])) 
						)] @
						[Rule(   
						[toValueLO (Constructor(execlo, [Var "L" ; Constructor(configuration, [(Var "Conf")])]))],
						 toStep (Constructor(configuration, [(Constructor(switchInherit, [Constructor(execlo, [Var "L" ; Constructor(configuration, [(Var "Conf")])])]))])) (Constructor(configuration, [Var("Conf")]))
					 	)] @					
						[Rule(   
						[toErrorLO (Constructor(execlo, [Var "L" ; Constructor(configuration, [(Var "Conf")])]))],
						 toStep (Constructor(configuration, [(Constructor(switchInherit, [Constructor(execlo, [Var "L" ; Constructor(configuration, [(Var "Conf")])])]))])) (Constructor(configuration, [Var("Conf")]))
					 	)]						
						
let addRuleToSwitchLanguage configurationDeclaration = 
	let configurationDeclaration = List.hd configurationDeclaration in  
	let argsInConf = List.mapi (toGenericVarByIndex "H") (term_getArguments configurationDeclaration) in 
	let ruleForValueConfiguration = [Rule([toValue (Var "E")], toValue (Constructor(configuration, Var("E") :: argsInConf)))] in 
	let ruleForErrorConfiguration = [Rule([toError (Var "E")], toError (Constructor(configuration, Var("E") :: argsInConf)))] in 
	let premiseNew = toStepLO (Var("E")) (Var("E'")) in 
	   [Rule([premiseNew] , wrap_in_configuration_formula argsInConf (toStep (Constructor(switchNew, [Var("E")])) (Constructor(switchNew, [Var("E'")]))))] @ (* new *)
	   (if argsInConf = [] then [] else (let premiseInherited = [toStepLO (foldbyApplications (Var("E") :: argsInConf)) (Var("E'")) ; Formula(extract_state, [Var("E'") ; Var("R")] @ List.map tick argsInConf)] in 
	   	[Rule(premiseInherited , wrap_in_configuration_formula argsInConf (toStep (Constructor(switchInherit, [Var("E")])) (Constructor(switchInherit, [Var("R")])))) ; 
		 Rule([], 
			 Formula(extract_state, 
				 [Constructor(execlo, [Var("L") ; 
				  Constructor(configuration, Var("E") :: argsInConf)]) ; 
				  wrapbyAbstractions (Constructor(execlo, [Var("L") ; Constructor(configuration, Var("E") :: List.map var_uncapitalize argsInConf)])) (List.map var_uncapitalize argsInConf)] 
			     @ argsInConf
			 ))])) @ (* inherited *)
(*  	   [Rule([Formula(extract_program, [(foldbyApplications ((Var("E")) :: argsInConf)) ; Var "E2"])] , wrap_in_configuration_formula_no_tick argsInConf (toStep (Constructor(switchInherit, [Var "E"])) (Var "E2")))] @ *) (* to release the value *)
		   [Rule([Formula(extract_program, [(foldbyApplications ((Var("E")) :: argsInConf)) ; Var "E2"])] , wrap_in_configuration_formula_no_tick argsInConf (toStep (Constructor(switchInherit, [Var "E"])) (Var "E2")))] @  (* to release the value *)
	  	   [Rule([toValueLO (Constructor(execlo, [Var "L" ; Constructor(configuration, (Var "E") :: argsInConf)]))] , Formula(extract_program, [Constructor(execlo, [Var "L" ; Constructor(configuration, (Var "E") :: argsInConf)]) ; Var "E"]))] @
	  	   [Rule([toErrorLO (Constructor(execlo, [Var "L" ; Constructor(configuration, (Var "E") :: argsInConf)]))] , Formula(extract_program, [Constructor(execlo, [Var "L" ; Constructor(configuration, (Var "E") :: argsInConf)]) ; Var "E"]))] @
		   ruleForValueConfiguration @ ruleForErrorConfiguration
	(* 
	
	let premise = wrap_in_exec_formula (wrap_in_configuration_formula argsInConf (toStepLO (Var("E")) (Var("E'")))) in 
	
	steps_inside_configurations must return a language to be added by exec before executing *)
	(* configurationDeclaration is an Option 
let steps_inside_configurations configurationDeclaration conf = 
	let configurationDeclaration = if is_none configurationDeclaration then Constructor("e", []) else get configurationDeclaration in 
	let argsInConf = List.mapi (toGenericVarByIndex "H") (term_getArguments configurationDeclaration) in 
	match conf with 
	| Constructor(op, args) -> let variablesInConclusion = List.mapi (toGenericVarByIndex "X") (List.tl args)  in 
	 						  let sourceOfConclusion = wrap_in_configuration (Constructor(op, (Var "E") :: variablesInConclusion)) argsInConf in 
	 						  let targetOfConclusion = wrap_in_configuration (Constructor(op, (Var "E'") :: variablesInConclusion)) argsInConf in 
							  	Language([], [Rule([toStep (Var "E") (Var "E'")], toStep sourceOfConclusion targetOfConclusion)])
	| _ -> raise(Failure("steps_inside_configurations"))
	
	let configurationDeclaration = if List.length configurationDeclaration = 1 then List.hd configurationDeclaration else raise(Failure("Configuration declaration has multiple items, this is ambiguous.")) in  
	
	
	*)