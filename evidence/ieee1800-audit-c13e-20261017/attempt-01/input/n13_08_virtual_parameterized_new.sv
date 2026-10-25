virtual class C#(parameter DECODE_W, parameter ENCODE_W = $clog2(DECODE_W));
  function new();
  endfunction
endclass

module n13_08_virtual_parameterized_new;
  C#(8) item;
  initial item = C#(8)::new;
endmodule
