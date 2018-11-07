open Batteries
open Lexing
open Option
open Batteries.Format
open Stream
open Elpi_API
open Elpi_API.Data
open Elpi_API.Ast
open Loml
open Compiler


exception TypeError of string 
let type_error msg = raise(TypeError(msg))

let infoLO = "infoLO"
let toInfoLO (var,typ) = Formula(infoLO, [Var var ; typeLO_to_termELPI typ])

let startingTyping_fromSwitch term termToPut = match term with 
	| Switch(n, Language(syntax, rules), dummyTerm) -> let (Formula(pred, initialArgs)) = rule_getConclusion (List.hd rules) in 
						(Formula(typing, List.map (term_substitute termToPut "C") (List.map turnGrammarNamesToVariables initialArgs)))
	| _ -> raise (TypeError ("StartingCall did not give readable information, I don't know how to type check"))

let typing_rule_for_multiple_args_in_conf syntax conf = match conf with Constructor("conf", args) -> 
	let configurationDeclaration = try Some (snd (List.assoc "Configuration" syntax)) with Not_found -> None in 
	if List.length args < 2 && is_none configurationDeclaration then ["typeOf GammaLO Gamma (switchInherit (exec E Conf)) T :- typeOfLO GammaLO E (tlanguage Rules), (Rules => (typeOf GammaLO Gamma Conf T)).
"] else 
	let startingCallDeclaration = try Some (snd (List.assoc "StartingCall" syntax)) with Not_found -> None in 
	if is_none startingCallDeclaration 
		then raise (TypeError ("Configuration does not contain information on how to type check ")) 
		else let term11 = Constructor(switchInherit,  [Constructor(execlo, [Var "E" ; Var "Conf"])]) in 
		[ generateFormula (startingTyping_fromSwitch (List.hd (get startingCallDeclaration)) term11)
		    ^ ":- typeOfLO GammaLO E (tlanguage Rules), (Rules => (" ^   
			 generateFormula (startingTyping_fromSwitch (List.hd (get startingCallDeclaration)) (Var "Conf")) ^ "))."
			]

(* this is a var because a list of formulae is not a term here, unlike in Lambda-Prolog, but we need to put a list of formulae as an argument *)
let compileContextToElpi gammaLO = Var ("[ " ^ (String.concat ", " (List.map generateFormula (List.map toInfoLO gammaLO))) ^ " ]")


let quantifyByVariables gammaLO formula = let variables = (List.map fst gammaLO) in 
											String.concat " " (List.map wrapInQuantifier variables) ^ " " ^ generateFormula formula ^ "."

(* here below, it also inserts GammaLO. Notice that this returns a string.  *)
let toTypeWithUnwrapConf gammaLO syntax conf = match conf with Constructor("conf", args) -> 
	let gammaLOasArgument = compileContextToElpi gammaLO in 
	let configurationDeclaration = try Some (snd (List.assoc "Configuration" syntax)) with Not_found -> None in 
	if is_none configurationDeclaration then quantifyByVariables gammaLO (Formula(typing, [gammaLOasArgument ; Var "[]"] @ args @ [Var "T"]))
	else
		let startingCallDeclaration = try Some (snd (List.assoc "StartingCall" syntax)) with Not_found -> None in 
		if is_none startingCallDeclaration 
			then raise (TypeError ("Configuration does not contain information on how to type check ")) 
			else quantifyByVariables gammaLO (startingTyping_fromSwitch (List.hd (get startingCallDeclaration)) conf)
			
		
let unwrapConf_1element conf = match conf with Constructor("conf", args) -> if args = [] then raise(TypeError("unwrapConf_1element failed: The type of a configuration seems to be empty"))  else List.hd args

let fromStringToTerm str = 
	 let _ = print_endline ("Raw result from ELPI: " ^ str) in 
	 if str = "X0\n" then Var("any") else
	let filebuf = Lexing.from_string ("a> (" ^ str ^ ")")  in 
		 	let exp = try (Parser.file Lexer.token filebuf) with 
						  | Lexer.Error msg -> raise(TypeError("Lexer error on configuration: " ^ str ^ " with message: " ^ msg))
						  | Parser.Error ->
						      		raise(TypeError("Parser error on configuration: " ^ str)) 
						in 
						match exp with (Exec(e, conf) :: rest) -> (* let _ = print_string (generateTerm (compile (Exec(e, conf)))) in *) unwrapConf_1element conf
	
let more () = false
;;

let result : (string option) ref = ref None

let get_result resultVariable time = function
| Elpi_API.Execute.NoMoreSteps -> result := None
| Elpi_API.Execute.Failure -> result := None
| Elpi_API.Execute.Success { assignments;
    constraints; 
    custom_constraints;
     } -> Elpi_API.Data.StrMap.iter (fun name v -> (* Format.fprintf str_formatter "%a\n" Elpi_API.Pp.term v *)
	 if name = resultVariable then Format.fprintf str_formatter "%a\n"  (* "  @[<hov 1>%a@]@\n%!"  *)
      Elpi_API.Pp.term v else () ) assignments; result := Some (flush_str_formatter ()); 
;;


let type_checking_configuration gammaLO syntax rules conf = 
	let conf = mute_switchInherit conf in 
(*	let asd = print_endline ("dopoSwitchSwitchato: " ^ (generateTerm conf)) in
	let asd = List.map (fun rule -> print_string (show_rule rule)) rules in 
	let asd = print_string ":ENDRULES" in 
*)	let rules = rules @ (addSubtyping syntax rules) in  (* if the language has declared subtyping, that expands in rules.  *)
	let switchTypingRules = typing_rule_for_multiple_args_in_conf syntax conf in 
(*	let _ = print_string ("switchrule: " ^ (String.concat "\n" switchTypingRules)) in *)
	let switchTypingRule = [Elpi_API.Parse.program_from_stream (Stream.of_string (String.concat "\n" switchTypingRules))] in 
(*	let _ = print_string ("after:" ^ show_exp (Language(syntax, rules))) in *)
	let _ = result := None in 
	 let prog = Elpi_API.Parse.program_from_stream (Stream.of_string (String.concat "\n" (List.map generateRule rules))) in 
	 let asd = print_endline ((String.concat "\n" (List.map generateRule rules)) ^ "----" ^ show_term conf ^ "----" ^ (String.concat "\n" switchTypingRules) ^ "----" ^ toTypeWithUnwrapConf gammaLO syntax conf); in 
	let query = Elpi_API.Parse.goal (toTypeWithUnwrapConf gammaLO syntax conf) in 
    let prog = Elpi_API.Compile.program (get !elpi_init) ([get !lomlImplementation] @ switchTypingRule @ [prog]) in
    let query = Elpi_API.Compile.query prog query in
	let vars =
	    ref Elpi_API.Compile.(default_flags.defined_variables) in
    let flags = {
      Elpi_API.Compile.default_flags
        with Elpi_API.Compile.defined_variables = !vars } in
	let exec = Elpi_API.Compile.link ~flags query in
		let _ = Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:(get_result "T"); in 
   		if is_some !result 
	 	   then try fromStringToTerm (get !result) with 
	  							| Lexer.Error msg -> raise(TypeError("Lexer error: " ^ msg))
  			  					| Parser.Error -> raise(TypeError("Parser error: "))
	 	   else type_error "Configuration does not type check"
		
	
	
		   (*
			   
		let initialDecl = (List.filter (fun decl -> match decl with | (Constructor("typecheck", initialArgs)) -> true | _ -> false) (get configurationDeclaration)) in 
		let Constructor(name, initialArgs) = if initialDecl = [] then raise (TypeError ("Configuration does not contain information on how to type check ")) else List.hd initialDecl in 
		let term11 = Constructor(switchInherit,  [Constructor(execlo, [Var "E" ; Var "Conf"])]) in 
		[ generateFormula (Formula(typing, [Var "GammaLO"] @ List.map (term_substitute term11 "C") initialArgs)) ^ ":- typeOfLO GammaLO E (tlanguage Rules), (Rules => (" ^   
			   generateFormula (Formula(typing, [Var "GammaLO"] @ List.map (term_substitute (Var "Conf") "C") initialArgs)) ^ "))."
		]
			   
			   
		   let typing_rule_for_multiple_args_in_conf syntax (Constructor("conf", args)) = 
		   	let configurationDeclaration = try Some (snd (List.assoc "Configuration" syntax)) with Not_found -> None in 
		   	if args = [] && is_none configurationDeclaration then ["typeOf GammaLO Gamma (switchInherit (exec E (conf Conf))) T :- typeOfLO GammaLO E (tlanguage Rules), (Rules => (typeOf GammaLO Gamma Conf T)).
		   "] else 
		   		let initialDecl = (List.filter (fun decl -> match decl with | (Constructor("typecheck", initialArgs)) -> true | _ -> false) (get configurationDeclaration)) in 
		   		let Constructor(name, initialArgs) = if initialDecl = [] then raise (TypeError ("Configuration does not contain information on how to type check ")) else List.hd initialDecl in 
		   		let argsInConf = List.mapi (toGenericVarByIndex "H") (List.tl args) in  (* tail args, because the first argument is E *)
		   		let term11 = Constructor(switchInherit,  [Constructor(execlo, [Var "E" ; Var "Conf"])]) in 
		   		let term21 = Constructor(configuration,  Constructor(switchInherit, [Var "E"]) :: argsInConf) in 
		   		let term22 = Constructor(switchInherit, [foldbyApplications (Var "E" :: argsInConf)]) in 
		   		[ generateFormula (Formula(typing, [Var "GammaLO"] @ List.map (term_substitute term11 "C") initialArgs)) ^ ":- typeOfLO GammaLO E (tlanguage Rules), (Rules => (" ^   
		   			   generateFormula (Formula(typing, [Var "GammaLO"] @ List.map (term_substitute (Var "Conf") "C") initialArgs)) ^ "))."
		   			; 
		   		  generateRule (Rule(
		   			  [Formula(typing, [Var "GammaLO"] @ List.map (term_substitute term22 "C") initialArgs)], 
		   			   Formula(typing, [Var "GammaLO"] @ List.map (term_substitute term21 "C") initialArgs)
		   		  		)) 
		   		]
		   *)
	

(*		
				| _ -> type_error "The type returned from a nested call was not understandable" (* Format.eprintf "Type: \n%s\n" (get !result); return (get !result); *)


let queryToTyping syntax conf = 
	let typeSystemSignature = try Some (snd (List.assoc "Type System" syntax)) with Not_found -> None in 
	let (Constructor(pred, args)) as tsTerm = from_signature_to_term typing typeSystemSignature in 
	let tsFormula = Formula(pred, Var "GammaLO" :: args) in 
	
	


let _ = result := None in 
		let cwd = Unix.getcwd () in
		  let tjpath =
		    let v = try Sys.getenv "TJPATH" with Not_found -> "" in
		    let tjpath = Str.split (Str.regexp ":") v in
		    List.flatten (List.map (fun x -> ["-I";x]) tjpath) in
		  let installpath = [ "-I"; "" ] in
		  let execpath = ["-I"; Filename.dirname (Sys.executable_name)] in
		  let opts = Array.to_list Sys.argv @ tjpath @ installpath @ execpath in
		  let pheader, argv = Elpi_API.Setup.init ~silent:true ~builtins:Elpi_builtin.std_builtins opts ~basedir:cwd in
		  let newRules = addGammaOfLOMLtoRules gamma rules in 
		 let prog = Elpi_API.Parse.program [(String.concat "\n" (List.map generateRule newRules))] in 
		let query = Elpi_API.Parse.goal (generateFormula (queryToTyping conf) ^ ".") in 
	    let prog = Elpi_API.Compile.program pheader [prog] in
	    let query = Elpi_API.Compile.query prog query in
		let vars =
		    ref Elpi_API.Compile.(default_flags.defined_variables) in
	    let flags = {
	      Elpi_API.Compile.default_flags
	        with Elpi_API.Compile.defined_variables = !vars } in
	    if not (Elpi_API.Compile.static_check pheader ~flags query) then
	       Format.eprintf "Type error\n";
		let exec = Elpi_API.Compile.link ~flags query in
			Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result;
	   		if is_some !result 
						then let returnType = Format.fprintf str_formatter "inType(%s)" (get !result) in flush_str_formatter; return returnType
						else return "";;
*)			
						
						(* type_error ("here typToSubst: " ^ show_typ typ1 ^ "here var: " ^ var ^ "here typToChange: " ^ show_typ typ2 ^ "and union = " ^ show_typ (
						
						else type_error ("In let, the expression is not of the type specified.: " ^ (show_typ typ) ^ "--" ^ (show_typ (type_checker delta ((var, typ) :: gamma) e1)) ^ "--" ^ (show_typ (type_checker delta ((var, typ) :: gamma) e2)) ^ "--" ^ string_of_bool (equality typ (type_checker delta ((var, typ) :: gamma) e1))) *)