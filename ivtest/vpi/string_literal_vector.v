module main;
 initial begin
   $literal_vector_probe("");
   $literal_vector_probe("A");
   $literal_vector_probe("ABC");
   $literal_vector_probe("ABCD");
   $literal_vector_probe("ABCDE");
   $literal_vector_probe("ABCDEFGH");
   $literal_vector_probe("ABCDEFGHI");
   $literal_vector_probe("\377\200\001\376\375");
   $literal_vector_probe("\000AB\000C");
   $display("LITERAL_VECTOR_PASSED");
 end
endmodule
