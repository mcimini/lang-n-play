{
  open Lexing
  open Parser
  exception Error of string


let next_line lexbuf =
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { pos with pos_bol = lexbuf.lex_curr_pos;
               pos_lnum = pos.pos_lnum + 1
    }

}

let var = ['a'-'z']['a'-'z' 'A'-'Z' '0'-'9' '_']*
let varTerm = ['A'-'Z']['a'-'z' 'A'-'Z' '0'-'9' '_']*

rule token = parse
    [' ' '\t']  { token lexbuf }
  | ['\r' '\n']  { next_line lexbuf; token lexbuf }
  | ['0'-'9']+           { INT (int_of_string(Lexing.lexeme lexbuf)) }
  | "true"               { TRUE }
  | "false"               { FALSE }
  | "if"            { IF }
  | "letrec"           { LETREC }  
  | "vv"               { VVLEX }
  | "ee"               { EELEX }
  | "U"               { UNION }
  | ">"               { EXEC }
  | "{!"             { LLAN }
  | "!}"             { RLAN }
  | "then"          { THEN }
  | "else"          { ELSE }
  | "let"           { LET }  
  | "in"           { IN }  
  | "subtyping"           { DECLARATIVESUB }  
  | "--new"           { NEWSTATE }  
  | "--copy"           { COPYSTATE }  
  | "--inherit"           { INHERITSTATE }  
  | "switch-to"           { SWITCH }  
  | "::="            { GRAMMARASSIGN }
  | "import"		{ IMPORT }
  | "remove"               { REMOVE }
  | "from"               { FROM }
  | "Relation"		{ RELATION }
  | "StartingCall"		{ STARTCALL }
  | "-"		{ MINUS }
  | "+"		{ PLUS }
  | "'"		{ ACCENT }
  | ","            { COMMA }
  | "."            { DOT }
  | "|-"            { TURNSTYLE }
  | "<=="            { PROVIDED }
  | "/\\"            { AND }
  | "-->"            { STEP }
  | "<:"            { SUBTYPING }
  | "|"               { MID }
  | "@"               { BIND }
  | "/x]"               { SUBST }
  | "[]"               { NIL }
  | "::"               { CONS }
  | ";"               { CONSLO }
  | "hd"               { HEAD }
  | "tl"               { TAIL }
  | '='             { EQUAL }
  | ':'             { COLON }
  | '('             { LPAREN }
  | ')'             { RPAREN }
  | '['             { LSQUARE }
  | ']'             { RSQUARE }
  | "->"            { ARROW }
  | "strategy"            { STRATEGYTYPE }
  | "bool"            { BOOL }
  | "contravariant"            { CONTRA }
  | "invariant"            { INVAR }
  | var             { VARLEX (Lexing.lexeme lexbuf) }
  | varTerm             { VARTERM (Lexing.lexeme lexbuf) }
  | eof             { EOF }
  | _
	    { raise (Error (Printf.sprintf "At offset %d: unexpected character %s.\n" (Lexing.lexeme_start lexbuf) (Lexing.lexeme lexbuf))) }
{
}