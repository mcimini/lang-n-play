open Batteries

let is_numeric str =
  try ignore (int_of_string str); true
  with _ -> false

let range a b =
    let rec aux a b =
      if a > b then [] else a :: aux (a+1) b  in
       if a > b then List.rev (aux b a) else aux a b

let getFormalVariables prefix n = if n = 0 then [] else
    let numbers = (range 1 n) in
    let getVars = (fun n -> (prefix^(string_of_int n))) in
    List.map getVars numbers 


let get3_1 (a, _, _) = a
let get3_2 (_, a, _) = a
let get3_3 (_, _, a) = a

let repeat obj n = if n = 0 then [] else 
    let numbers = (range 1 n) in
    let getRepeat = (fun n -> obj) in
    List.map getRepeat numbers 

let nthMinusOne myList n = 
	List.nth myList (n-1) 

let stringReplace input output =
    Str.global_replace (Str.regexp_string input) output;;

let find obj myList = 
	let getIndex = fun obj1 -> fun index -> fun obj2 -> if obj1 = obj2 then index+1 else 0 in 
		List.fold_left max 0 (List.mapi (getIndex obj) myList)

let findIndicesByPred pred myList = 
	let getIndex = fun pred -> fun index -> fun el -> if pred el then index+1 else 0 in 
	List.filter (fun n -> n>0) (List.mapi (getIndex pred) myList)
let decrement n = n-1

let safeTail myList = if myList = [] then [] else List.tl myList
 
let withSpaces = String.concat " "

let removeDuplicates(list') =
  let rec removeDuplicatesHelper(list) = match List.rev(list) with
  |[]->[]
  |head::tail -> if List.mem head tail then
                  removeDuplicatesHelper(List.rev(tail))
                 else [head]@removeDuplicatesHelper(List.rev(tail))
  in List.rev(removeDuplicatesHelper(list'));;

let addAnd str = " /\\ " ^ str

let list_subset a b = List.for_all (fun x -> List.mem x b) a

let list_difference a b = let notpresent x = not (List.mem x b) in List.filter notpresent a 


let ck p message = if p then true else raise(Failure message)
let ckIf p action message = if p then action else raise(Failure message)

let fillToPairs (a, l) = List.map (fun el -> (a,el)) l

let getAllValuesForKey l c1 = let selected = List.filter (fun ((c2,i), variance) -> c1 == c2) l in (c1, List.map (fun ((c2,i), variance) -> (i,variance)) selected)
let getAllArrangedByKey l = List.map (getAllValuesForKey l) (removeDuplicates (List.map (fun ((c,i), variance) -> c) l))

let list_deleteAt l i = List.take i l @ List.drop (i+1) l

let chop_last_char str chr =
    if String.get str ((String.length str) - 1) = chr then String.sub str 0 ((String.length str) - 1) else str
	
let startsWith str1 str2 = str2 = String.sub str1 0 (String.length str2)
let endsWith str1 str2 = str2 = String.sub str1 0 (String.length str2)
let dropLastInString str1 n = String.sub str1 0 ((String.length str1) - n) 
