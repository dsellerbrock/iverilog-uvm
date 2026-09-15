class packed_holder;
  logic [15:0] value;
  function new(logic [15:0] initial_value); value=initial_value; endfunction
endclass

module sv_class_packed_select_incdec;
  packed_holder first, second, current;
  int base_calls;
  function automatic int rebind_base(input int base);
    base_calls++;
    current=second;
    return base;
  endfunction
  initial begin
    logic [3:0] result;
    logic bit_result;
    first=new(16'ha55a); second=new(16'h3cc3); current=first; base_calls=0;
    result=current.value[rebind_base(4)+:4]++;
    if (result!==4'h5 || first.value!==16'ha56a || second.value!==16'h3cc3 ||
        current!=second || base_calls!=1) $fatal(1,"part receiver/index capture");
    current=first; base_calls=0;
    bit_result=++current.value[rebind_base(1)];
    if (bit_result!==0 || first.value!==16'ha568 || second.value!==16'h3cc3 ||
        current!=second || base_calls!=1) $fatal(1,"bit receiver/index capture");
    $display("PASSED");
  end
endmodule
