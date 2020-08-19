open Batteries
open Batteries.Format
open Elpi_API
open Elpi_API.Data
open Elpi_API.Ast
open Option
open Loml
open Compiler

let queryToValue program = [toNStepLO program (Var "Result") ; toValueLO (Var "Result")]  (* you should add ; toValueLO (Var "Result") to premises *)
let queryToError program = [toNStepLO program (Var "Result")  ; toErrorLO (Var "Result")] (* you should add ; toValueLO (Var "Result") to premises *)
let queryToStuck program = [toStuck program (Var "Result")] (* you should add ; toValueLO (Var "Result") to premises *)
let queryToException program = [toNStepLO program (Var "Result") ; toException (Var "Result")] (* you should add ; toValueLO (Var "Result") to premises *)

let more () = false
;;

let result : (string option) ref = ref None

let get_result time = function
| Elpi_API.Execute.NoMoreSteps -> result := None
| Elpi_API.Execute.Failure -> result := None
| Elpi_API.Execute.Success { assignments;
    constraints; 
    custom_constraints;
     } -> Elpi_API.Data.StrMap.iter (fun name v -> Format.fprintf str_formatter "  @[<hov 1>%a@]@\n%!"
      Elpi_API.Pp.term v) assignments; result := Some (flush_str_formatter ()); 
;;

let evaluate program = 
	let _ = result := None in 
	 let _ = print_string ("ELPI Execution: " ^ generatePremises [] (queryToValue program) ^ ".\n\n") in 	
	let query = Elpi_API.Parse.goal (generatePremises [] (queryToValue program) ^ ".") in 
    let prog = Elpi_API.Compile.program (get !elpi_init) [get !lomlImplementation] in
    let query = Elpi_API.Compile.query prog query in
	let vars =
	    ref Elpi_API.Compile.(default_flags.defined_variables) in
    let flags = {
      Elpi_API.Compile.default_flags
        with Elpi_API.Compile.defined_variables = !vars } in
    if not (Elpi_API.Compile.static_check (get !elpi_init) ~flags query) then
       Format.eprintf "Type error\n";
	let exec = Elpi_API.Compile.link ~flags query in
		Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result;
   		if is_some !result 
	 	   then Format.eprintf "Value produced: \n%s\n" (get !result) (* (generateTerm (get !result)) *)
	 	   else begin
			    let query = Elpi_API.Parse.goal (generatePremises [] (queryToError program) ^ ".") in 
		   	    let query = Elpi_API.Compile.query prog query in
				let exec = Elpi_API.Compile.link ~flags query in
				Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result;
   	 			if is_some !result 
					then Format.eprintf "Error produced: \n%s\n" (get !result)  (* (generateTerm (get !result)) *)
					else begin 	
			   		let query = Elpi_API.Parse.goal (generatePremises [] (queryToException program) ^ ".") in 
			   	    let query = Elpi_API.Compile.query prog query in
					let exec = Elpi_API.Compile.link ~flags query in
					Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result;
						if is_some !result 
						   then Format.eprintf "Evaluation produced an exception: \n%s\n" (get !result)
					       else begin
		   			   		let query = Elpi_API.Parse.goal (generatePremises [] (queryToStuck program) ^ ".") in 
		   			   	    let query = Elpi_API.Compile.query prog query in
		   					let exec = Elpi_API.Compile.link ~flags query in
		   					Elpi_API.Execute.loop ~delay_outside_fragment:false exec ~more ~pp:get_result;
		   						if is_some !result 
		   						   then Format.eprintf "Evaluation did not produce a value nor an error, got stuck at the program: \n%s\n" (get !result)
		   					       else begin Format.eprintf "Evaluation did not produce a value nor an error\n" end
							end
					end		
     			 end
	;;
		


(* 
			
let queryToValue program = Rule([toNStepLO program (Var "Result")], toMain (Var "Result"))  (* you should add ; toValueLO (Var "Result") to premises *)
let queryToError program = Rule([toNStepLO program (Var "Result")], toMain (Var "Result"))  (* you should add ; toValueLO (Var "Result") to premises *)
			
			
			valueLO (strategy Formula).  
			generateRule (queryToValue program) ^ "."
			result := Some (elpi_term_to_my_term (v))
		
		Elpi_API.Data.assignments; arg_names; constraints; custom_constraints
					
let printQuery program = print_string (generateRule (mainQuery program)); print_string (show_typ (type_checker [] [] program));;
				
	 run_elpi true [p] g; print_string (String.concat "\n" !result)

    result :=  Format.eprintf "  @[<hov 1>%s = %a@]@\n%!" 
	(name ^ " = " ^ 
      (dump (Elpi_API.Pp.term)) ^ (dump assignments.(i))) :: !result ) arg_names ;;


	(* let pheader, argv let p = program ["loml"] in *) let (a, b) = Elpi_API.Setup.init ~silent:false ~builtins:[] ~basedir:cwd opts in 

open Elpi_API.Parse
open Elpi_API.Compile
open Elpi_API.Data
*)