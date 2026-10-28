module issue1248_leaf;
  initial $display("CELL=%l UPPER=%L HIER=%m");
endmodule

module issue1248_library_display;
  issue1248_leaf u();
  initial #1 $finish;
endmodule
