module test;
  string left = "a";
  string right = "b";
  string sink;

  function automatic string join_values;
    join_values = {left, right};
  endfunction

  assign sink = join_values();

  initial begin
    #1;
    if (sink != "ab") $fatal(1, "function initial: %s", sink);
    right = " longer";
    #1;
    if (sink != "a longer") $fatal(1, "function dependency: %s", sink);
    $display("PASS string function dependency");
  end
endmodule
