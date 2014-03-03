(* type 'a mult_node = T of 'a * 'a mult_node;; *)

(* ANI: identifier = identifier, typ = type *)
type identifier = IDENT of int * string


and cm = CM of clas list

(*                    name of formal, type of formal *)
and formals = FORMAL of identifier * identifier

(* INT(line_no, value) *)
and case_element = CE of identifier * identifier * expr
                  (*            name,         typ *)
and let_binding = LB_NO_INIT of identifier * identifier
                  (*  name,       typ          some expr *)
	| LB_INIT of identifier * identifier * expr

and expr = INT of int * int
	| STRING of int * string
	| ASSIGN of int * identifier * expr 
	| DYN_DISPATCH of int * expr * identifier * expr list
	| STAT_DISPATCH of int * expr * identifier * identifier * expr list
	| SELF_DISPATCH of int * identifier * expr list
	| IF_ELSE of int * expr * expr * expr
	| WHILE of int * expr * expr
	| BLOCK of int * expr list
	| NEW of int * identifier
	| ISVOID of int * expr
	| PLUS of int * expr * expr
	| MINUS of int * expr * expr
	| TIMES of int * expr * expr
	| DIVIDE of int * expr * expr
	| LT of int * expr * expr
	| LE of int * expr * expr
	| EQ of int * expr * expr
	| NOT of int * expr
	| NEGATE of int * expr
	| TRUE of int
	| FALSE of int
	| LET of int * let_binding list * expr
	| CASE of int * expr * case_element list
	| IDENTIFIER of int * identifier

              (*           fname,        type,       no_init or init with expr *)
and feature = ATTRIBUTE of identifier * identifier * expr option
                    (* name,     return type,  () or list,   not-opt *)
	| METHOD of identifier * identifier * formals list * expr

(*                  name of class, optional inheritance, number of features, features list *)
and clas = CLASS of identifier * identifier option * int * feature list

(* number of classes, class list *)
and program = PROGRAM of int * clas list;;

let failure line_no message = print_endline (Printf.sprintf ("ERROR: %d: Type-Check: %s") line_no message)

(****************************  BUILD THE AST FROM FILE  ************************************)
let rec binding_list lines num_bindings = match num_bindings with
	0 -> (lines, [])
|	_ -> match lines with
			"let_binding_init" :: line_no :: ident :: type_line_no :: type_name :: lines ->
				let (rem_lines, expr) = build_expr lines in
				let (rem_lines, binding_nodes) = binding_list rem_lines (num_bindings-1) in
				let line_num = int_of_string line_no
				and type_line_num = int_of_string type_line_no in
				(rem_lines, LB_INIT( IDENT(line_num, ident), IDENT(type_line_num, type_name), expr) :: binding_nodes)
		| "let_binding_no_init" :: line_no :: ident :: type_line_no :: type_name :: lines ->
				let (rem_lines, binding_nodes) = binding_list lines (num_bindings-1) in
				let line_num = int_of_string line_no
				and type_line_num = int_of_string type_line_no in
				(rem_lines, LB_NO_INIT( IDENT(line_num, ident), IDENT(type_line_num, type_name)) :: binding_nodes ) 
		|  _ -> (lines, [])

and expr_list lines num_exprs = match num_exprs with
	0 -> (lines, [])
|	_ -> 
	let (rem_lines, expr) = build_expr lines in
	let (rem_lines, expr_list) = expr_list rem_lines (num_exprs-1) in
	(rem_lines, expr :: expr_list)

and build_identifier lines = match lines with
	line_no :: ident :: lines ->
		(lines, IDENT((int_of_string line_no), ident))
|	_ -> failure 0 "badtree";
             ([], IDENT(0, ""))

and case_element_list lines num_elems = match num_elems with
	0 -> (lines, [])
|	_ -> match lines with
		line_no :: name :: typ_line_no :: typ :: lines ->
			(* Printf.printf "Found case elem on line: %s with name: %s and type: %s\n" line_no name typ; *)
			let (rem_lines, expr) = build_expr lines in
			let (rem_lines, elem_list) = case_element_list rem_lines (num_elems -1) in
			let line_num = int_of_string line_no
			and typ_line_num = int_of_string typ_line_no in
			(rem_lines, CE( IDENT(line_num, name), IDENT(typ_line_num, typ), expr ) :: elem_list)
                | _ -> failure 0 "badtree"; ([], [])

and build_expr lines = match lines with
    line_no :: "integer" :: num :: rem_lines -> 
		(rem_lines, INT((int_of_string line_no), (int_of_string num)))
|   line_no :: "string" :: word :: rem_lines ->
		(rem_lines, STRING( (int_of_string line_no), word))
|   line_no :: "assign" :: iden_line_no :: name :: lines  ->
		let (rem_lines, expr) = build_expr lines in
		let line_num = int_of_string line_no
		and iden_line_num = int_of_string iden_line_no in
		( rem_lines, ASSIGN( line_num, IDENT(iden_line_num, name), expr) )
|   line_no :: "let" :: num_bindings :: lines ->
		let (rem_lines, bindings) = binding_list lines (int_of_string num_bindings) in
		let (rem_lines, expr) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		( rem_lines, LET(line_num, bindings, expr) )
|   line_no :: "case" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let num_elems  = List.hd rem_lines in
                let rem = List.tl rem_lines in
		let (rem_lines, case_elements) = case_element_list rem (int_of_string num_elems) in
		( rem_lines, CASE( (int_of_string line_no), expr, case_elements ))
|   line_no :: "if" :: lines ->
		let (rem_lines, expr) = build_expr lines in
		let (rem_lines, expr1) = build_expr rem_lines in
		let (rem_lines, expr2) = build_expr rem_lines in
		(rem_lines, IF_ELSE( (int_of_string line_no), expr, expr1, expr2 ) )
|   line_no :: "le" :: lines ->
		let (rem_lines, expr) = build_expr lines in
		let (rem_lines, expr2) = build_expr rem_lines in
		(rem_lines, LE( (int_of_string line_no), expr, expr2 ) )
|   line_no :: "identifier" :: ident_line_no :: ident :: lines ->
		let line_num = int_of_string line_no
		and ident_line_num = int_of_string ident_line_no in
		(lines, IDENTIFIER( line_num, IDENT( ident_line_num, ident) ) )
|   line_no :: "while" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let (rem_lines, expr2) = build_expr rem_lines
		and line_num = int_of_string line_no in
		(rem_lines, WHILE(line_num, expr, expr2) )
|   line_no :: "block" :: num_exprs :: lines ->
		let (rem_lines, exprs) = expr_list lines (int_of_string num_exprs) in
		let line_num = int_of_string line_no in
		(rem_lines, BLOCK( line_num, exprs ))
|   line_no :: "plus" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, PLUS(line_num, lhs, rhs ) )
|   line_no :: "minus" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, MINUS(line_num, lhs, rhs ) )
|   line_no :: "times" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, TIMES( line_num, lhs, rhs ))
|   line_no :: "divide" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, DIVIDE( line_num, lhs, rhs ))
|   line_no :: "lt" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, LT( line_num, lhs, rhs ))
|   line_no :: "eq" :: lines -> 
		let (rem_lines, lhs) = build_expr lines in
		let (rem_lines, rhs) = build_expr rem_lines in
		let line_num = int_of_string line_no in
		(rem_lines, EQ( line_num, lhs, rhs ))
|   line_no :: "not" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let line_num = int_of_string line_no in
		(rem_lines, NOT( line_num, expr ))
|   line_no :: "negate" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let line_num = int_of_string line_no in
		(rem_lines, NEGATE( line_num, expr ))
|   line_no :: "isvoid" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let line_num = int_of_string line_no in
		(rem_lines, ISVOID( line_num, expr ))
|   line_no :: "new" :: ident_no :: ident :: lines ->
		let line_num = int_of_string line_no 
		and ident_line_num = int_of_string ident_no in
		(lines, NEW( line_num, IDENT(ident_line_num, ident)))
|   line_no :: "true" :: lines -> 
		let line_num = int_of_string line_no in
		(lines, TRUE(line_num))
|   line_no :: "false" :: lines -> 
		let line_num = int_of_string line_no in
		(lines, FALSE(line_num))
|   line_no :: "self_dispatch" :: meth_line_no :: meth :: num_exprs :: lines -> 
		let (rem_lines, exprs) = expr_list lines (int_of_string num_exprs) in
		let line_num = int_of_string line_no
		and ident_line_num = int_of_string meth_line_no in
		(rem_lines, SELF_DISPATCH( line_num, IDENT(ident_line_num, meth), exprs ) )
|   line_no :: "dynamic_dispatch" :: lines -> 
		let (rem_lines, expr) = build_expr lines in
		let (rem_lines, ident) = build_identifier rem_lines in
		let num_exprs = List.hd rem_lines in
		let (rem_lines, exprs) = expr_list rem_lines (int_of_string num_exprs) in
		let line_num = int_of_string line_no in
		(rem_lines, DYN_DISPATCH(line_num, expr, ident, exprs))
		(* match rem_lines with
			ident_line_no :: ident :: num_exprs :: lines ->
				let (rem_lines, exprs) = expr_list lines (int_of_string num_exprs) in
				let line_num = int_of_string line_no 
				and ident_line_num = int_of_string ident_line_no in
				(rem_lines, DYN_DISPATCH(line_num, expr, IDENT(ident_line_num, ident), exprs))
		|   [] -> (rem_lines, DYN_DISPATCH(0, expr, IDENT(0, ""), [])) *)
|   line_no :: "static_dispatch" :: lines -> 

		let (rem_lines, expr) = build_expr lines in
		let (rem_lines, ident1) = build_identifier rem_lines in
		let (rem_lines, ident2) = build_identifier rem_lines in
		let num_exprs = List.hd rem_lines in
                let rem_lines = List.tl rem_lines in
		let (rem_lines, exprs) = expr_list rem_lines (int_of_string num_exprs) in
		let line_num = int_of_string line_no in
		(rem_lines, STAT_DISPATCH(line_num, expr, ident1, ident2, exprs))

		(* match rem_lines with
			typ_line_no :: typ :: method_line_no :: meth :: num_exprs :: lines ->
				let (rem_lines, exprs) = expr_list lines (int_of_string num_exprs) in
				let typ_line_num = int_of_string typ_line_no
				and method_line_num = int_of_string method_line_no
				and line_num = int_of_string line_no in
				(rem_lines, STAT_DISPATCH(line_num, expr, IDENT(typ_line_num, typ), IDENT(method_line_num, meth), exprs))
		|   [] -> (rem_lines, STAT_DISPATCH(0, expr, IDENT(0, ""), IDENT(0, ""), [])) *)
|   _ -> ([], STRING(0, "DIFFERENT EXPRESSION"))
;;

let rec formal_list lines num_formals = match num_formals with 
	0 -> (lines, [])
|   _ -> match lines with
			line_no :: name :: type_line_no :: type_name :: rem_lines -> begin
				let (rem, formals) = formal_list rem_lines (num_formals - 1) in
				let line_num = int_of_string line_no
				and type_line_num = int_of_string type_line_no in
				(rem, FORMAL( IDENT(line_num, name), IDENT(type_line_num, type_name) ) :: formals ) 
			end
                |	_ -> failure 0 "badtree"; ([], [])
;;

let rec feature_list lines num_features = match num_features with
	0 -> (lines, [])
|   _ -> match lines with
			"attribute_no_init" :: line_no :: name :: type_line_no :: t :: lines -> begin
					let (rem, feature_nodes) = feature_list lines (num_features-1) in
					let (line_num, type_line_num) = ( (int_of_string line_no), (int_of_string type_line_no)) in
					(rem, ATTRIBUTE(IDENT(line_num, name), IDENT(type_line_num, t), None) :: feature_nodes );
				end
		|   "attribute_init" :: line_no :: name :: type_line_no :: type_name :: lines -> begin
					let (rem_lines, expr) = build_expr lines in
					let (rem, feature_nodes) = feature_list rem_lines (num_features-1) in
					let line_num = int_of_string line_no
					and type_line_num = int_of_string type_line_no in
					(rem, ATTRIBUTE( IDENT(line_num, name), IDENT(type_line_num, type_name), Some(expr)) :: feature_nodes );
				end
		|   "method" :: line_no :: name :: num_formals :: lines -> 		
					let (lines, formals_nodes) = formal_list lines (int_of_string num_formals) in
					let (rem_lines, typ_ident) = build_identifier lines in
					let (rem_lines, expr) = build_expr rem_lines in

					(* Get the rest of the features in this class and the remaining lines after those *)
					let (rem, feature_nodes) = feature_list rem_lines (num_features-1) in
					let line_num = int_of_string line_no in
					(rem, METHOD( IDENT(line_num, name), typ_ident, formals_nodes, expr) :: feature_nodes )
		| 	_ -> ([], [])
;;

let rec class_list lines num_classes = match num_classes with
	0 -> []
|	_ -> match lines with
			line_no :: name :: "no_inherits" :: num_features :: lines -> begin
				let (rem_lines, feat_nodes) = feature_list lines (int_of_string num_features) in
				let line_num = int_of_string line_no in
				CLASS( IDENT(line_num, name), None, (int_of_string num_features), feat_nodes ) :: (class_list rem_lines (num_classes-1));
			end
		|  line_no :: name :: "inherits" :: type_line_no :: type_name :: num_features :: lines -> begin
				let (rem_lines, feat_nodes) = feature_list lines (int_of_string num_features) in
				let line_num = int_of_string line_no
				and type_line_num = int_of_string type_line_no in
				CLASS( IDENT(line_num, name), Some(IDENT(type_line_num, type_name)), (int_of_string num_features), feat_nodes) :: (class_list rem_lines (num_classes-1));
			end
		|   _ -> []
;;

let ast lst = match lst with
	num_classes :: lines -> PROGRAM((int_of_string num_classes) , (class_list lines (int_of_string num_classes) ) )
|   [] -> PROGRAM(0, []);;



(************************* CLASS MAP BUILDING ***************************)
let ai typ = IDENT(0, typ)

let obj = Some(ai "Object") ;;
(* predefined classes in cool *)
let predefd = [CLASS(ai "Bool", obj, 0, []); CLASS(ai "Int", obj, 0, []); 
              CLASS(ai "Object", None, 0, []); CLASS(ai "String", obj, 0, []);
              CLASS(ai "IO", obj, 0, [])] ;;

let rec cm_attribute feat_list = match feat_list with
    [] -> []

|   ATTRIBUTE( name, typ, Some(expr)) :: tl ->
		(* Add this attribute and print as initializer*)
                ATTRIBUTE(name, typ, Some(expr)) :: (cm_attribute tl)

|   ATTRIBUTE( name, typ, None) :: tl -> 
		(* Add this attribute and print as no_initializer *)
                ATTRIBUTE(name, typ, None) :: (cm_attribute tl)
|   _ :: tl -> 
		(* Ignore everything else *)
		cm_attribute tl

and cm_class_list ast = match ast with
	CLASS( name, Some(typ), num_feats, feats) ->
	       CLASS(name, Some(typ), num_feats, (cm_attribute feats))

    |   CLASS( name, None, num_feats, feats) -> 
               CLASS(name, obj, num_feats, (cm_attribute feats))


and add_check_names class_list = 
                let class_names = List.map (fun c -> 
                                                let CLASS(ident, _, _, _) = c in
                                                let IDENT(ln, name) = ident in name
                                           )
                                           class_list in
                if not (List.mem "Main" class_names) then failure 0 "class Main not found";
                class_list @ predefd

and class_map ast = 
    let PROGRAM(num_classes, class_list) = ast in
    (* Add this class node to the class map *)
    let class_list = add_check_names (List.map cm_class_list class_list) in
    let sorted_list = List.sort (fun a b -> match (a, b) with 
                                                (CLASS(name, _, _, _), CLASS(name2, _, _, _)) ->  compare name name2
                                            ) class_list in
     (* add inherited attrs *)
     CM(sorted_list)  ;;




(*******************************  PRINTING HELPER METHODS *******************************)

let print_list lst = List.iter (fun a -> print_string (a ^ "\n")) lst;;

let print_identifier ident oc = match ident with
	IDENT(line_no, str) -> 
			Printf.fprintf oc "%d\n%s\n" line_no str;
			(* Printf.printf "%d\n%s\n" line_no str *)

;;

let rec print_bindings bindings oc = match bindings with
	[] -> ()
|	LB_NO_INIT(ident, typ) :: tl  -> 
				Printf.fprintf oc "let_binding_no_init\n";
				print_identifier ident oc;
				print_identifier typ oc;
				print_bindings tl oc;
|	LB_INIT(ident, typ, expr) :: tl ->
				Printf.fprintf oc "let_binding_init\n";
				print_identifier ident oc;
				print_identifier typ oc;
				print_expr oc expr;
				print_bindings tl oc;

and print_case_elements elems oc = match elems with
	[] -> ()
|   hd :: tl -> match hd with 
		CE (a, b, e) ->
			print_identifier a oc;
			print_identifier b oc;
			print_expr oc e;
			print_case_elements tl oc

and print_expr oc expr = match expr with
	INT(line_no, value) -> Printf.fprintf oc "%d\ninteger\n%d\n" line_no value
|	STRING (line_no, str) -> Printf.fprintf oc "%d\nstring\n%s\n" line_no str
|   DYN_DISPATCH (line_no, e, meth,  exprs) ->
					Printf.fprintf oc "%d\ndynamic_dispatch\n" line_no;
					print_expr oc e;
					print_identifier meth oc;
					Printf.fprintf oc "%d\n" (List.length exprs);
					List.iter (print_expr oc) exprs;
|   STAT_DISPATCH (line_no, e, typ, meth, exprs) -> 
					Printf.fprintf oc "%d\nstatic_dispatch\n" line_no;
					print_expr oc e;
					print_identifier typ oc;
					print_identifier meth oc;
					Printf.fprintf oc "%d\n" (List.length exprs);
					List.iter (print_expr oc) exprs;
|   SELF_DISPATCH (line_no, meth, exprs) -> 
					Printf.fprintf oc "%d\nself_dispatch\n" line_no;
					print_identifier meth oc;
					Printf.fprintf oc "%d\n" (List.length exprs);
					List.iter (print_expr oc) exprs;
|   CASE (line_no, expr, elems) -> 
					Printf.fprintf oc "%d\ncase\n" line_no;
					print_expr oc expr;
					Printf.fprintf oc "%d\n" (List.length elems);
					print_case_elements elems oc;
|   ASSIGN (line_no, ident, expr) -> 
					Printf.fprintf oc "%d\nassign\n" line_no;
					print_identifier ident oc;
					print_expr oc expr;
|   LET (line_no, bindings, expr) ->
					Printf.fprintf oc "%d\nlet\n%d\n" line_no (List.length bindings);
					print_bindings bindings oc;
					print_expr oc expr;
|   IF_ELSE (line_no, expr1, expr2, expr3) -> 
					Printf.fprintf oc "%d\nif\n" line_no;
					print_expr oc expr1;
					print_expr oc expr2;
					print_expr oc expr3;
|   WHILE (line_no, expr, expr1) -> 
					Printf.fprintf oc "%d\nwhile\n" line_no;
					print_expr oc expr;
					print_expr oc expr1;
|   BLOCK (line_no, exprs) ->
					Printf.fprintf oc "%d\nblock\n%d\n" line_no (List.length exprs);
					List.iter (print_expr oc) exprs;
|   IDENTIFIER (line_no, ident) -> 
					Printf.fprintf oc "%d\nidentifier\n" line_no;
					print_identifier ident oc;
|   PLUS (line_no, lhs, rhs) -> 
					Printf.fprintf oc "%d\nplus\n" line_no;
					print_expr oc lhs;
					print_expr oc rhs;
|   MINUS (line_no, lhs, rhs) -> 
					Printf.fprintf oc "%d\nminus\n" line_no;
					print_expr oc lhs;
					print_expr oc rhs;
|   TIMES (line_no, lhs, rhs) -> 
					Printf.fprintf oc "%d\ntimes\n" line_no;
					print_expr oc lhs;
					print_expr oc rhs;
|   DIVIDE (line_no, lhs, rhs) -> 
					Printf.fprintf oc "%d\ndivide\n" line_no;
					print_expr oc lhs;
					print_expr oc rhs;
|   LT (line_no, lhs, rhs) ->
					Printf.fprintf oc "%d\nlt\n" line_no;
					print_expr oc lhs;
					print_expr oc rhs;
|   LE (line_no, expr1, expr2) -> 
					Printf.fprintf oc "%d\nle\n" line_no;
					print_expr oc expr1;
					print_expr oc expr2;
|   EQ (line_no, expr1, expr2) -> 
					Printf.fprintf oc "%d\neq\n" line_no;
					print_expr oc expr1;
					print_expr oc expr2;
|   NOT (line_no, expr) -> 
					Printf.fprintf oc "%d\nnot\n" line_no;
					print_expr oc expr;
|   NEGATE (line_no, expr) -> 
					Printf.fprintf oc "%d\nnegate\n" line_no;
					print_expr oc expr;
|   ISVOID (line_no, expr) -> 
					Printf.fprintf oc "%d\nisvoid\n" line_no;
					print_expr oc expr;
|   NEW (line_no, ident) -> 
					Printf.fprintf oc "%d\nnew\n" line_no;
					print_identifier ident oc;
|   TRUE (line_no) ->
					Printf.fprintf oc "%d\ntrue\n" line_no; 
|   FALSE (line_no) ->
					Printf.fprintf oc "%d\nfalse\n" line_no;
;;

let print_formal oc formal = match formal with
	FORMAL(a, b) -> 
		print_identifier a oc;
                print_identifier b oc;
;;


let rec print_feature_list feat_list oc = match feat_list with
	[] -> ()
|   hd :: tl -> match hd with
            ATTRIBUTE(ident, typ, None) -> 
							Printf.fprintf oc "attribute_no_init\n";
							print_identifier ident oc;
							print_identifier typ oc;
							print_feature_list tl oc;
	|   ATTRIBUTE(ident, typ, Some(expr)) ->
	 						Printf.fprintf oc "attribute_init\n";
							print_identifier ident oc;
							print_identifier typ oc;
							print_expr oc expr;
							print_feature_list tl oc;
	|   METHOD(name, typ, formals, expr) -> 
							Printf.fprintf oc "method\n";
							print_identifier name oc;
							Printf.fprintf oc "%d\n" (List.length formals);
							List.iter (print_formal oc) formals;
							print_identifier typ oc;
							print_expr oc expr;
							print_feature_list tl oc;
;;

let rec print_class_list class_list oc = match class_list with
	[] -> ()
        |   hd :: tl -> match hd with
            CLASS(ident, None, num_features, feat_list) -> 
                                                        print_identifier ident oc;
                                                        Printf.fprintf oc "no_inherits\n";
                                                        Printf.fprintf oc "%d\n" num_features;
                                                        print_feature_list feat_list oc;
                                                        print_class_list tl oc;
	|   CLASS(ident, Some(inher), num_features, feat_list) -> 
                                                        print_identifier ident oc;
                                                        Printf.fprintf oc "inherits\n";
                                                        print_identifier inher oc;
                                                        Printf.fprintf oc "%d\n" num_features;
                                                        print_feature_list feat_list oc;
                                                        print_class_list tl oc;
;;


(**************************** CLASS MAP PRINTING ***************************)
let print_cm_attr oc feat = match feat with
        ATTRIBUTE(ident, typ, None) -> 
							Printf.fprintf oc "no_initializer\n";
                                                        let IDENT(ln, name) = ident in
                                                        let IDENT(ln, typ) = typ in
                                                        Printf.fprintf oc "%s\n" name;
                                                        Printf.fprintf oc "%s\n" typ;
    |   ATTRIBUTE(ident, typ, Some(expr)) ->
	 						Printf.fprintf oc "initializer\n";
                                                        let IDENT(ln, name) = ident in
                                                        let IDENT(ln, typ) = typ in
                                                        Printf.fprintf oc "%s\n" name;
                                                        Printf.fprintf oc "%s\n" typ;
                                                        print_expr oc expr;
    (* if method do nothing! *)
    |   _ -> ()
    ;;

let print_class_map class_map oc = match class_map with 
    CM(class_list) ->
        Printf.fprintf oc "class_map\n";
        Printf.fprintf oc "%d\n" (List.length class_list);
        List.map (fun cm_class -> match cm_class with 
                                              CLASS(name_i, _, _, feats) ->
                                                  let IDENT(_, name) = name_i in
                                                  Printf.fprintf oc "%s\n%d\n" name (List.length feats);
                                                  List.map (print_cm_attr oc) feats;
                 ) class_list;
;;

let rec print_ast ast oc = match ast with
	PROGRAM(num_classes, class_list) -> 
				Printf.fprintf oc "%d\n" num_classes;
				print_class_list class_list oc;
;;

let filename = match Array.length (Sys.argv) with
		2 -> Array.get Sys.argv 1
	|   _ -> failwith "Please provide a single file command line arguments"
;;

         

let lines = ref [] in
let in_file = open_in filename in
try
	while true do
		let line = input_line in_file in
		lines := line :: !lines;
	done
with
| _ -> begin
	let cool_input = (List.rev !lines) in
	(* print_list cool_input; *)
	let p = ast cool_input in

	(* Open output file, returning a channel to write to *)
	let file = "out.cl-type" in
	let oc = open_out file in
        let classMap = class_map p in 
        (* since print_class_map has side-effects we must ignore it *)
        ignore(print_class_map classMap oc);
	print_ast p oc; 
	close_out oc;
end
	