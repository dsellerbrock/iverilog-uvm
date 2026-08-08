// Associative-array no-parentheses properties: size and num are aliases.
// IEEE 1800-2017 7.9.1: both report the current number of entries.

module test;
  typedef enum int { RED = 4, BLUE = 9 } color_e;

  int aa[int];
  int by_string[string];
  int by_enum[color_e];

  class holder;
    int values[int];

    function int counts();
      return values.size + values.num;
    endfunction
  endclass

  holder h;

  initial begin
    h = new;
    if (aa.size !== 0 || aa.num !== 0) begin
      $display("FAILED empty size=%0d num=%0d", aa.size, aa.num);
      $finish(1);
    end

    // Both methods return a signed int. Comparing their zero result with
    // an unsized -1 distinguishes signed from unsigned 32-bit lowering.
    if (!(aa.size > -1) || !(aa.num > -1)
        || !(aa.size() > -1) || !(aa.num() > -1)) begin
      $display("FAILED signed int result");
      $finish(1);
    end

    aa[3] = 1;
    if (aa.size !== 1 || aa.num !== 1) begin
      $display("FAILED one size=%0d num=%0d", aa.size, aa.num);
      $finish(1);
    end

    aa[16'hffff] = 2;
    aa[4'b1000] = 3;
    if (aa.size !== 3 || aa.num !== 3) begin
      $display("FAILED three size=%0d num=%0d", aa.size, aa.num);
      $finish(1);
    end

    aa.delete(16'hffff);
    if (aa.size !== 2 || aa.num !== 2) begin
      $display("FAILED delete size=%0d num=%0d", aa.size, aa.num);
      $finish(1);
    end

    if (aa.size !== aa.size() || aa.num !== aa.num()) begin
      $display("FAILED parenthesized parity size=%0d/%0d num=%0d/%0d",
               aa.size, aa.size(), aa.num, aa.num());
      $finish(1);
    end

    by_string["key"] = 4;
    by_enum[BLUE] = 5;
    if (by_string.size !== 1 || by_string.num !== 1
        || by_enum.size !== 1 || by_enum.num !== 1) begin
      $display("FAILED key kinds string=%0d/%0d enum=%0d/%0d",
               by_string.size, by_string.num, by_enum.size, by_enum.num);
      $finish(1);
    end

    h.values[7] = 6;
    if (h.counts() !== 2) begin
      $display("FAILED class-property counts=%0d", h.counts());
      $finish(1);
    end
    if (!(h.values.size > -1) || !(h.values.num > -1)
        || !(h.values.size() > -1) || !(h.values.num() > -1)) begin
      $display("FAILED class-property signed int result");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
