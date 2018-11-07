open Batteries
open Option
open Aux
open Loml
open Lexing

let get_positions lexbuf = let pos = lexbuf.lex_curr_p in pos.pos_fname ^ ":" ^ string_of_int pos.pos_lnum  ^ ":" ^ string_of_int (pos.pos_cnum - pos.pos_bol + 1)

let import_names = ref [] 

let rec read_file_list filename = 
	if List.mem filename !import_names then raise(Failure("The language definition " ^ filename ^ " has cyclic import declarations.")) else let a = import_names := filename :: (!import_names) in 
	let input = (open_in filename) in 
 	(let filebuf = Lexing.from_input input in 
(*	(let filebuf = Lexing.from_string "a> (elementAt (succ zero) (cons zero (cons zero (cons zero emptyList))))"  in *)
		 	let exp = try pre_process_import (Parser.file Lexer.token filebuf) with 
						   | Lexer.Error msg -> raise(Failure("Lexer error: " ^ get_positions filebuf ^ " with message: " ^ msg))
						  | Parser.Error ->
						      		raise(Failure("Parser error: " ^ get_positions filebuf)) in 
		   IO.close_in input; exp)
		   (* expander takes LetLO LetLO Import LetLO Import .. and returns ALL LetLO: LetLO LetLO LetLO LetLo input *)
and expander declaration = match declaration with 
	| (Import filename) -> read_file_list filename
	| other -> [other]
and pre_process_import declarations = List.concat (List.map expander declarations) 
		
let rec pre_processor_letLO_fold declarations = match declarations with 
	| [] -> raise(Failure("Syntax Error: programs is empty")) (* This shouldn't occur because the parser requires at least one expr *)
	| [lastExpr] -> lastExpr
	| ((LetLO(var, e1, e2)) :: rest) -> LetLO(var, e1, pre_processor_letLO_fold rest)
	
let read_file filename = pre_processor_letLO_fold (read_file_list filename)


(*	(let filebuf = Lexing.from_string "let references = {! Types T ::= (ref T) !} in references"  in *)
