module main;
  class c; endclass
  c object;
  logic q;
  function automatic c get_object(); return object; endfunction
  initial q = get_object();
endmodule
