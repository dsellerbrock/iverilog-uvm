module probe_nb_chandle_to_int;
  chandle ch;
  int i;
  initial i <= ch;
endmodule

module probe_valid_nb_chandle_copy;
  chandle a, b;
  initial a <= b;
endmodule

module probe_valid_nb_chandle_null;
  chandle a;
  initial a <= null;
endmodule

module probe_chandle_continuous;
  chandle a, b;
  assign a = b;
endmodule

module probe_chandle_initializer;
  chandle ch;
  int i = ch;
endmodule

module probe_chandle_function_argument;
  chandle ch;
  int i;
  function automatic int f(input int value);
    return value;
  endfunction
  initial i = f(ch);
endmodule

module probe_chandle_function_return;
  chandle ch;
  int i;
  function automatic int f;
    return ch;
  endfunction
  initial i = f();
endmodule

module probe_chandle_event_control;
  chandle ch;
  int i;
  initial begin
    @(ch);
    i = 1;
  end
endmodule

module probe_chandle_procedural_assign;
  chandle ch;
  int i;
  initial begin
    assign i = ch;
    deassign i;
  end
endmodule

module probe_chandle_force;
  chandle ch;
  int i;
  initial begin
    force i = ch;
    release i;
  end
endmodule
