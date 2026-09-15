module sv_class_packed_select_incdec_nested;
  class inner_holder; logic [7:0] value; endclass
  class outer_holder; inner_holder inner; endclass
  outer_holder outer; inner_holder first, second; int calls;
  function automatic int base(); calls++; outer.inner=second; return 0; endfunction
  initial begin outer=new; first=new; second=new; first.value=8'ha5; second.value=8'hc3; outer.inner=first; calls=0;
    begin logic [3:0] result; result=outer.inner.value[base()+:4]++;
      if(outer.inner!=second || first.value!==8'ha6 || second.value!==8'hc3 || result!==4'h5 || calls!=1)
        $fatal(1,"nested receiver was not captured before index evaluation");
    end
    $display("PASSED"); end
endmodule
