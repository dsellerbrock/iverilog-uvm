// IEEE1800-2017/2023 8.6,13.5: output destinations use the caller activation.
module sv_recursive_output_actual;
  class C;
    function int produce(output int value);
      value = 37;
      return 0;
    endfunction
    function void recurse(int depth);
      int seen = -1;
      if (depth != 0) begin
        recurse(produce(seen));
        if (seen != 37) $fatal(1, "caller output was %0d, expected 37", seen);
      end
    endfunction
  endclass
  initial begin
    C c;
    c = new;
    c.recurse(1);
    $display("PASSED");
  end
endmodule
