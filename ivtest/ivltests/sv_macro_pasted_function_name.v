`define pick(X) ((X)+1)
`define pick3(X) ((X)+30)
`define pick3tail(X) ((X)+300)
`define pick_word(X) ((X)+40)
`define call(N,X) `pick``N(X)
`define call_nested(N,X) `call(N,X)
`define multiple(K,T,X) `pick``K``T(X)
`define with_space(X) `pick`` (X)
`define before_paren(X) `pick``(X)
`define direct_call(X) `pick(X)
`define OBJ obj
`define OBJ_tail wrong
`define object_paste `OBJ``_tail
`define quote(X) `"X`"
module sv_macro_pasted_function_name;
  initial begin
    if (`call(3,12) != 42) $fatal(1,"numeric suffix");
    if (`call_nested(3,12) != 42) $fatal(1,"nested paste");
    if (`multiple(3,tail,12) != 312) $fatal(1,"multiple suffixes");
    if (`call(_word,12) != 52) $fatal(1,"identifier suffix");
    if (`before_paren(12) != 13) $fatal(1,"delimiter before arguments");
    if (`with_space(12) != 13) $fatal(1,"whitespace before arguments");
    if (`direct_call(12) != 13) $fatal(1,"ordinary call");
    if (`quote(`object_paste) != "obj_tail") $fatal(1,"object boundary");
    $display("PASSED");
  end
endmodule
