
(* The type of tokens. *)

type token = 
  | VVLEX
  | VARTERM of (string)
  | VARLEX of (string)
  | UNION
  | TURNSTYLE
  | TRUE
  | THEN
  | SUBTYPING
  | SUBST
  | STRATEGYTYPE
  | STEP
  | RULEMARK
  | RSQUARE
  | RPAREN
  | RLAN
  | PROVIDED
  | PLUS
  | NEWSTATE
  | MINUS
  | MID
  | LSQUARE
  | LPAREN
  | LLAN
  | LET
  | INT of (int)
  | INHERITSTATE
  | IN
  | IMPORT
  | IF
  | GRAMMARASSIGN
  | FUN
  | FRAGMENT
  | FALSE
  | EXEC
  | EQUAL
  | EOF
  | ELSE
  | EELEX
  | DECLARATIVESUB
  | COPYSTATE
  | COMMA
  | COLON
  | BIND
  | ARROW
  | AND
  | ACCENT

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val mystring: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Loml.exp)

val file: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Loml.exp list)
