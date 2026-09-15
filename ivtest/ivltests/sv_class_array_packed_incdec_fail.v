class box;
  const logic [7:0] values[0:1];
  function new;
    values = '{8'ha5, 8'h5a};
  endfunction
endclass
module sv_class_array_packed_incdec_fail;
  box b;
  initial begin
    b = new;
    b.values[0][3:0]++;
  end
endmodule
