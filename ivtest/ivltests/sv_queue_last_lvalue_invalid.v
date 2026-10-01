class last_receiver;
  int q[$];
endclass
module test;
  int dynamic_values[];
  int associative_values[int];
  bit [7:0] vector_value;
  last_receiver rec[$];
  function int pick();
    return 0;
  endfunction
  initial begin
    dynamic_values[$]=1;
    associative_values[$]=2;
    vector_value[$]=1'b1;
    rec[pick()].q[$]=3;
  end
endmodule
