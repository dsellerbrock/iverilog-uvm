// IEEE 1800-2017/2023 13.5.3: output defaults bind to the declaration scope.

module test();

integer a;
integer b;
integer c;

task k(input integer i = a, output integer j = b);
  j = i;
endtask

integer result;

reg fail = 0;

initial begin
  a = 1;
  b = 2;

  k(3,c);
  $display(a,,b,,c);
  if (a !== 1 || b !== 2 || c !== 3) fail = 1;

  k(,c);
  $display(a,,b,,c);
  if (a !== 1 || b !== 2 || c !== 1) fail = 1;

  k(4,);
  $display(a,,b,,c);
  if (a !== 1 || b !== 4 || c !== 1) fail = 1;

  k();
  $display(a,,b,,c);
  if (a !== 1 || b !== 1 || c !== 1) fail = 1;

  if (fail)
    $display("FAILED");
  else
    $display("PASSED");
end

endmodule
