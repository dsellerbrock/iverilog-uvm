// IEEE1800-2017/2023 8.6,13.5: output destinations use the caller activation.
module sv_recursive_output_index;
  class Box; int value; endclass
  class C;
    function int choose(int index); return index; endfunction
    function int produce(int depth, output int result);
      int slots[2];
      Box holder;
      int index = depth;
      int ignored;
      slots[0] = -1; slots[1] = -1;
      holder = new; holder.value = -1;
      if (depth == 0) begin result = 37; return 0; end
      ignored = produce(0, slots[choose(index)]);
      if (slots[0] != -1 || slots[1] != 37)
        $fatal(1, "caller slots %0d %0d", slots[0], slots[1]);
      ignored = produce(0, holder.value);
      if (holder.value != 37)
        $fatal(1, "caller property receiver");
      return 0;
    endfunction
  endclass
  initial begin
    C c;
    int ignored, result;
    c = new;
    ignored = c.produce(1, result);
    $display("PASSED");
  end
endmodule
