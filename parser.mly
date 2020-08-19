%{
  open Loml
%}

%token <string> VARLEX
%token <int> INT
%token TRUE FALSE
%token IF THEN ELSE
%token EQUAL 
%token LPAREN RPAREN
%token LSQUARE RSQUARE
%token LET IN 
%token VVLEX EELEX
%token REMOVE 
%token EXEC 
%token LLAN RLAN 

%token BIND  
%token SUBST  

%token <string> VARTERM
%token MID
%token GRAMMARASSIGN

%token COMMA
%token PROVIDED
%token COLON
%token TURNSTYLE
%token AND
%token STEP
%token SUBTYPING
%token DECLARATIVESUB

%token RELATION
%token STARTCALL

%token NEWSTATE 
%token COPYSTATE 
%token INHERITSTATE 
%token SWITCH

%token IMPORT 

%token ARROW
%token STRATEGYTYPE
%token BOOL

%token MINUS
%token PLUS
%token ACCENT

%token NIL
%token CONS
%token CONSLO
%token HEAD
%token TAIL

%token CONTRA
%token INVAR

%token LETREC

%token UNION 
%token FROM  

%token DOT

%left EXEC

%token EOF

%start file
%type <Loml.exp list> file

%start mystring
%type <Loml.exp> mystring

%start term
%type <Loml.term> term

%%

file:
  | EOF
    { [] }
  | e = expr EOF
    { [e] }
  | e = declOrImports lst = file
    { e :: lst }

declOrImports : 
  | LET var = VARLEX args = list(typedVar) EQUAL e1 = expr 
    { if args = [] then LetLO (var, e1, VarLO "") else LetLO (var, makeAbstraction args e1, VarLO "")} 
  | IMPORT file = VARLEX
    { Import(file ^ extensionFiles) }
	
mystring:
  | e = expr 
    { e }
| EOF
  { VarLO "EOF" }
| e = expr EOF
  { e }

valueGr : 
	| lan = language
	  { lan }
	| n = INT
	  { Int n }
    | VVLEX    
      { VV }
    | EELEX
      { EE }

language :
	| LLAN categories = option(separated_list(COMMA, syntax_category)) ruleList = option(rules) RLAN
  		{ Language(option_to_list categories, option_to_list ruleList) }

expr:
  | LET var = VARLEX args = list(typedVar) EQUAL e1 = expr IN e2 = expr
    { if args = [] then LetLO (var, e1, e2) else LetLO(var, makeAbstraction args e1, e2) } 
  | x = VARLEX
    { VarLO x }
  | e1 = expr UNION e2 = expr
	{ Union(e1, e2) }
  | e = expr EXEC terms = list(term)
    { Exec(e, Constructor(configuration, terms)) }
    | e = expr pre = VARLEX post = VARLEX EXEC terms = list(term)
      { let _ = prepost := true in ExecPrePost(e, pre, post, Constructor(configuration, terms)) }
  | IF e1 = expr THEN e2 = expr ELSE e3 = expr
    { If (e1, e2, e3) }
  | REMOVE LPAREN r = rule RPAREN FROM e = expr
  	{ Remove(r, e) }
  | TRUE
    { TT }
  | FALSE
    { FF }
  | LSQUARE elements = separated_list(CONSLO, expr) RSQUARE
    { makeCons elements }
  | LETREC var = VARLEX typ = typeGrammar VARLEX args = list(typedVar) EQUAL e1 = expr IN e2 = expr
    { if args = [] then LetLO (var, e1, e2) else LetrecLO(var, typ, makeAbstraction args e1, e2) } 
  | HEAD e = expr
    { HeadLO(e)}
  | TAIL e = expr
    { TailLO(e)}
  | LPAREN e = expr RPAREN	
    { e }    
  | LPAREN e1 = expr e2 = expr RPAREN
    { AppLO (e1, e2) }
  | v = valueGr 
    { v } 
 
term :  
  | LPAREN op = VARLEX termList = list(term) RPAREN	
    { Constructor(op, termList) } 
  | varname = VARTERM
    { Var(varname) }
  | op = VARLEX
    { detect_var_or_op op } 
  | BIND varname = VARLEX t = term
    { Abs(varname,t) } 
  | term1 = term LSQUARE term2 = term SUBST
    { Application(term1,term2) } 
  | LPAREN SWITCH n = option(INT) e = expr EXEC t = term RPAREN
    { Switch(InheritState (option_to_number n), e, t) }
| LPAREN SWITCH n = option(INT) e = expr pre = VARLEX post = VARLEX EXEC t = term RPAREN
  { let _ = prepost := true in SwitchPrePost(InheritState (option_to_number n), e, pre, post, t) }	
  | term1 = term COLON term2 = term   
    { Constructor(colon, [term1 ; term2]) }	
    | NIL  
      { Constructor(nil, []) }	
    | LSQUARE term1 = termOrColon MID term2 = termOrColon RSQUARE
      { Constructor(cons, [term1 ; term2]) }	
    | LSQUARE term1 = termOrColon RSQUARE
        { Constructor(cons, [term1]) }	

rule : 
  | f = formula 
    { Rule([], f) }
  | f = formula PROVIDED formulaList = separated_list(AND, formula)
    { Rule(formulaList, f) }
  | DECLARATIVESUB varianceOpt = option(COLON myvariance = separated_list(MID, variance) { myvariance })
  { let args = option_to_list varianceOpt in Rule([], Formula(declarativeSubtyping, args)) }

formula : 
  | f = prefixedFormula 
    { f }
  | f = simple_formula 
    { f }

prefixedFormula :
  | context = list(term) TURNSTYLE term1 = term COLON term2 = term output_context = list(term)
    { Formula(typing, [Var "GammaLO"] @ context @ [term1 ; term2] @ output_context) } 
  | terms1 = list(term) STEP terms2 = list(term)
    { Formula(step, [Constructor(configuration, terms1) ; Constructor(configuration, terms2)]) }
  | term1 = term SUBTYPING term2 = term
    { Formula(subtyping, [term1 ; term2]) }
  | term1 = term IN term2 = term 
    { Formula(member, [term1 ; term2]) }
	
simple_formula :
  | LPAREN pred = VARLEX termList = list(term) RPAREN
    { Formula(pred, termList) }

syntax_category : 
	| RELATION GRAMMARASSIGN formulaList = separated_list(MID, formula)	
    { ("Relation", ("", embedInSwitch formulaList)) }
	| STARTCALL GRAMMARASSIGN formulaList = separated_list(MID, formula)	 DOT
    { ("StartingCall", ("", embedInSwitch formulaList)) }
  	| category = VARTERM grammarvar = anyvar GRAMMARASSIGN termList = separated_list(MID, term)	
    { (category, (grammarvar, termList)) }

rules : 
  | ruleList = separated_list(COMMA, rule)  
    { ruleList }
alsoRules : 
  | COMMA ruleList = rules
    { ruleList }

termOrColon : 
  | t = term 
    { t }	
  | term1 = term COLON term2 = term   
    { Constructor(colon, [term1 ; term2]) }	
  | NIL  
    { Constructor(nil, []) }	
  | term1 = termOrColon CONS term2 = termOrColon   
    { Constructor(cons, [term1 ; term2]) }	
		
anyvar : | grammarvar = VARLEX { grammarvar } | grammarvar = VARTERM { grammarvar } 

stateflag : 
  | NEWSTATE { NewState }
  | COPYSTATE n = INT { CopyState n}
  | INHERITSTATE n = INT { InheritState n}

typedVar :
  | var = VARLEX COLON typ = typeGrammar	
    { (var, typ) }
  | ACCENT var = VARLEX 	
    { (var, TVar(var)) }
	
typeGrammar :
  | t1 = typeGrammar ARROW t2 = typeGrammar
    { TArrow(t1, t2) }
  | STRATEGYTYPE
    { TStrategy }
  | BOOL
    { TBool }
  | myvar = option(ACCENT var = VARLEX UNION { var }) mainLan = language lanToRemove = option(MINUS lanToRemove = language { lanToRemove})
    { TLanguage(language_getSyntax mainLan, language_getRules mainLan, toConstraints myvar lanToRemove) }
  | LPAREN t = typeGrammar RPAREN	
    { t } 
	   
variance :
  | CONTRA var = VARLEX position = INT	
    { (Constructor(contravariant, [Var var ; Var (string_of_int position)] )) } 
  | INVAR var = VARLEX position = INT	
    { (Constructor(invariant, [Var var ; Var (string_of_int position)] )) } 
  