module top;
  wire a, b;
  alias a = b;

  initial begin
    #1;
    $probe_alias_stmt;
    $finish;
  end
endmodule
