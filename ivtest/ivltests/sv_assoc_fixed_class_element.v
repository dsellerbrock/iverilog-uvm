// IEEE 1800-2017/2023 7.8: OpenTitan flash_ctrl class properties hold
// enum-keyed fixed arrays; selected writes allocate independent key values.
typedef enum bit { Data, Info } part_t;

class cfg;
  bit [1:0] tgt[part_t][0:1];

  function void check();
    if (tgt.exists(Data) || tgt.exists(Info)) $fatal(1, "initial keys");
    if (tgt[Data][0] !== 2'd0 || tgt.exists(Data))
      $fatal(1, "absent class-property key read");
    tgt[Data][0] = 2'd1;
    tgt[Info][1] = 2'd2;
    if (!tgt.exists(Data) || !tgt.exists(Info)
        || tgt[Data][0] !== 2'd1 || tgt[Data][1] !== 2'd0
        || tgt[Info][0] !== 2'd0 || tgt[Info][1] !== 2'd2)
      $fatal(1, "class-property fixed slots or per-key storage");
    tgt[Info] = tgt[Data];
    tgt[Data][0] = 2'd3;
    if (tgt[Info][0] !== 2'd1 || tgt[Info][1] !== 2'd0)
      $fatal(1, "class-property aggregate copy");
    tgt.delete(Data);
    if (tgt.exists(Data) || !tgt.exists(Info)
        || tgt[Info][0] !== 2'd1)
      $fatal(1, "class-property delete");
  endfunction
endclass

module top;
  cfg c;
  initial begin
    c = new;
    c.check();
    $display("PASSED");
  end
endmodule
