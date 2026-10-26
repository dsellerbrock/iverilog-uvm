class DuplicateConstraints;
  rand bit value;
  constraint same_name { value == 1'b0; }
  constraint same_name { value == 1'b1; }
endclass
module main;
  DuplicateConstraints item;
  initial item = new;
endmodule
