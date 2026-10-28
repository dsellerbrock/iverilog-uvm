module issue1248_leaf;
  initial begin
    $display("CELL=%l UPPER=%L HIER=%m");
    $write("WIDTH=[%12l] LEFT=[%-12L]\n");
    $display("PASSED");
  end
endmodule

module issue1248_library_binding;
  issue1248_leaf u();
endmodule
