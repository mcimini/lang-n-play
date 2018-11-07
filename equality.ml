open Batteries
open Option
open Batteries.Format
open Stream
open Elpi_API
open Elpi_API.Data
open Elpi_API.Ast
open Loml
open Compiler



let more () = false
;;

let result : (string option) ref = ref None

let get_result time = function
| Elpi_API.Execute.NoMoreSteps -> result := None
| Elpi_API.Execute.Failure -> result := None
| Elpi_API.Execute.Success { assignments;
    constraints; 
    custom_constraints;
     } -> Elpi_API.Data.StrMap.iter (fun name v -> Format.fprintf str_formatter "%a\n"  (* "  @[<hov 1>%a@]@\n%!"  *)
      Elpi_API.Pp.term v) assignments; result := Some (flush_str_formatter ()); 
;;


let test_equality_with_ELPI query = 
	let _ = result := None in 
	let query = Elpi_API.Parse.goal (query) in 
    let prog = Elpi_API.Compile.program (get !elpi_init) [get !lomlImplementation] in
    let query = Elpi_API.Compile.query prog query in
	let vars =
	    ref Elpi_API.Compile.(default_flags.defined_variables) in
    let flags = {
      Elpi_API.Compile.default_flags
        with Elpi_API.Compile.defined_variables = !vars } in
	let exec = Elpi_API.Compile.link ~flags query in
		let _ = Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result; in 
   		  is_some !result 


let equality typ1 typ2 = 
	begin
	match typ1 with 
		| TLanguage(syntax1, rules1, varAndConstraints1) -> 
			begin match typ2 with 
			| TLanguage(syntax2, rules2, varAndConstraints2) -> 
				let rules1 = List.map rule_add_valuehood rules1 in 
				let rules2 = List.map rule_add_valuehood rules2 in 
				let query = ("list_equality " ^ generateTerm (List.hd (compile_rules rules1)) ^ " " ^ generateTerm (List.hd (compile_rules rules2)) ^ ".") in
	(*			let _ = print_string ("QUERY: " ^ query) in 
				equality_syntax syntax1 syntax2 && 
				equality_query varAndConstraints1 varAndConstraints2 && *)
				test_equality_with_ELPI query
			| _ -> false
			end
		| LAMBDA(var, typ) ->  test_equality_with_ELPI (generateTerm (typeLO_to_termELPI typ1) ^ " = " ^ generateTerm (typeLO_to_termELPI typ2) ^ ".") 
		| LambdaSTR(var, typ) -> test_equality_with_ELPI (generateTerm (typeLO_to_termELPI typ1) ^ " = " ^ generateTerm (typeLO_to_termELPI typ2) ^ ".") 
		| _ -> typ1 = typ2
	end
		
		
	
	

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