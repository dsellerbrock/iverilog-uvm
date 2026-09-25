module tb;
  bit [31:0] two;
  function automatic int invalid(ref logic [31:0] data);
    data = 'x;
    return 1;
  endfunction
  initial begin
    invalid(two);
  end
endmodule
