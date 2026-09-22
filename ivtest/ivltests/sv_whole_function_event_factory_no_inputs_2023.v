module sv_whole_function_event_factory_no_inputs;
 class leaf_t;
  function int value(); return 0; endfunction
 endclass
 function automatic leaf_t receiver();
  leaf_t made=new;
  $display("FACTORY_EVALUATED");
  return made;
 endfunction
 bit woke;
 initial begin
  fork begin @(receiver().value());woke=1;end join_none
  #1 if(woke)$fatal(1,"constant receiver woke");
  $display("PASS factory no inputs");$finish;
 end
endmodule
