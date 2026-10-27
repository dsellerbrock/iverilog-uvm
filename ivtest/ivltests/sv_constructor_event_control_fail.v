// IEEE 1800-2017/2023 8.7: a constructor is a function and cannot wait.
class sv_constructor_event_control_holder;
  event ready;
  function new();
    @ready;
  endfunction
endclass

module sv_constructor_event_control_fail;
  sv_constructor_event_control_holder obj;
  initial obj = new;
endmodule
