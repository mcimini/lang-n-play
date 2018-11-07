OCAML=ocamlfind ocamlc -w "-8-10-11-14-25-26" -g -package menhirLib -package batteries -package ppx_deriving.eq -package ppx_deriving.show -package elpi -linkpkg -thread 
OUTPUT=lofl
GENERATEDDIR=generated/

default:
	ocamllex lexer.mll
	menhir parser.mly
	$(OCAML) aux.ml loml.ml declarations.ml parser.mli parser.ml lexer.ml preprocessor.ml compiler.ml equality.ml typeCheckerConfiguration.ml typeChecker.ml evaluator.ml main.ml -o $(OUTPUT)
	
clean:
	rm *.cmo
	rm *.cmi
	rm $(OUTPUT)

