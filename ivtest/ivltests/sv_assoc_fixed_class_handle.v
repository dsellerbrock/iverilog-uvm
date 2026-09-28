// IEEE 1800-2017/2023 7.8: OpenTitan flash_ctrl keeps backdoor utility
// handles in enum-keyed fixed arrays; array copies retain handle identity.
typedef enum bit { Data, Info } part_t;

class entry;
  int value;
  function new(int value); this.value = value; endfunction
endclass

class cfg;
  entry tgt[part_t][2:1];
  entry first;

  function void check();
    if (tgt[Data][1] != null || tgt.exists(Data))
      $fatal(1, "absent handle read inserted key");
    first = new(5);
    tgt[Data][1] = first;
    if (!tgt.exists(Data) || tgt[Data][2] != null)
      $fatal(1, "handle defaults");
    tgt[Info] = tgt[Data];
    tgt[Data][1] = new(7);
    if (tgt[Info][1] != first || tgt[Info][1].value != 5)
      $fatal(1, "array value copy");
    first.value = 6;
    if (tgt[Info][1].value != 6)
      $fatal(1, "handle identity");
    tgt.delete(Data);
    if (tgt.exists(Data) || !tgt.exists(Info) || tgt[Info][1] != first)
      $fatal(1, "delete independence");
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
