// Hierarchical foreach syntax must reach lowering, then fail explicitly
// when unsupported. A parsed but discarded constraint is not a success.
class dev_t;
  rand int unsigned size[3];
endclass

class item;
  rand int unsigned idx;
  rand int unsigned device_id;

  dev_t lookup[4];

  function new();
    foreach (lookup[i]) lookup[i] = new;
  endfunction

  task go();
    void'(randomize() with {
        device_id inside {[0:3]};
        foreach (lookup[device_id].size[i]) {
          lookup[device_id].size[i] < 10;
        }
    });
  endtask
endclass

module main;
  initial begin
    item it;
    it = new;
    it.go();
    if (it.device_id < 0 || it.device_id > 3) begin
      $display("FAILED device_id=%0d out of the resolvable range", it.device_id);
      $finish;
    end
    $display("PASSED");
  end
endmodule
