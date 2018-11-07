open Batteries
open Elpi_API
open Elpi_API.Data
open Elpi_API.Ast
open Elpi_API.Setup
open Loml
open Preprocessor 
open Compiler 
open TypeChecker 
open Evaluator 

let main () =
	let cwd = Unix.getcwd () in
	  let tjpath =
	    let v = try Sys.getenv "TJPATH" with Not_found -> "" in
	    let tjpath = Str.split (Str.regexp ":") v in
	    List.flatten (List.map (fun x -> ["-I";x]) tjpath) in
	  let installpath = [ "-I"; "" ] in
	  let execpath = ["-I"; Filename.dirname (Sys.executable_name)] in
	  let opts = Array.to_list Sys.argv @ tjpath @ installpath @ execpath in
	  let pheader, argv = Elpi_API.Setup.init ~silent:true ~builtins:Elpi_builtin.std_builtins opts ~basedir:cwd in
 	  let _ = elpi_init := Some pheader; lomlImplementation := Some (Elpi_API.Parse.program [language_implementation])
 in 
 if Sys.argv.(1) = "--untyped" then let exp = read_file (Sys.argv.(2)) in evaluate (compile_ exp) else
 let exp = read_file (Sys.argv.(1)) in 
 (* let asd = print_string ("AFTERPARSING:" ^ show_exp exp ^ ":ENDAFTERPARSING\n")  in *)
    (*  let (typ, newexp) = type_checker true [] [] exp in 
	 print_string (generateTerm (compile newexp)); 
	evaluate program*)
	let (typ, exp) = type_checker 0 [] [] exp in 
	let (typ, newexp) = type_checker 1 [] [] exp in 
		 (* let (typ, newexp) = type_checker true [] [] exp in print_string (show_typ typ)
 		 print_string (show_exp exp); print_string (show_exp newexp); *)
		 print_endline (show_exp newexp); 
		 print_endline ("Type of the program: " ^ show_typ (fst (type_checker 2 [] [] newexp)) ^ "\n\n") ; 
		 print_endline ("Program to be evaluated: " ^ (show_term (compile_ exp)) ^ "\n\n"); 
		  evaluate (compile_ exp) 

let _ = main ()
