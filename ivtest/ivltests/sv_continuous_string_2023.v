module test;
string path;
assign path = "out.txt";
initial begin
  #1;
  if (path != "out.txt") $fatal(1, "continuous string value: %s", path);
  $display("PASS continuous string");
end
endmodule
