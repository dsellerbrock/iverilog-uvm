// An indexed receiver may have side effects; diagnose until it is evaluated.
class leaf;
  int value;
endclass
class holder;
  leaf m[int][2];
endclass
module top;
  holder boxes[1];
  int calls;
  function int next_idx(); calls++; return 0; endfunction
  initial begin
    boxes[0] = new;
    foreach (boxes[next_idx()].m[,bank])
      $fatal(1, "indexed receiver was silently discarded");
  end
endmodule
