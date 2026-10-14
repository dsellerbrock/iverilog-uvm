// IEEE 1800-2017/2023 12.7.3: evaluate the indexed parent before traversing
// the fixed child dimension after an omitted associative key.
class leaf;
  int value;
  function new(int v); value = v; endfunction
endclass

class holder;
  leaf m[int][2:1];
endclass

module top;
  holder boxes[1];
  int calls;
  int visits;

  function automatic int next_idx();
    calls++;
    return 0;
  endfunction

  initial begin
    boxes[0] = new;
    boxes[0].m[5][2] = new(22);
    boxes[0].m[5][1] = new(11);

    foreach (boxes[next_idx()].m[, bank]) begin
      if (bank != 2 - visits)
        $fatal(1, "wrong fixed child index: %0d", bank);
      if (boxes[0].m[5][bank].value != bank * 11)
        $fatal(1, "wrong selected parent value at bank %0d", bank);
      visits++;
    end

    if (calls != 1 || visits != 2)
      $fatal(1, "parent calls/child visits=%0d/%0d", calls, visits);
    $display("PASSED");
  end
endmodule
