interface descendant_if;
  logic [1:0] value;
endinterface

class descendant_cfg;
  virtual descendant_if vif;
  int hits;
endclass

class recursive_watcher;
  task automatic descend(int depth, descendant_cfg cfg);
    if (depth) begin
      descend(depth - 1, cfg);
    end else begin
      fork begin
        @(posedge (cfg.vif.value == 2'b10));
        cfg.hits++;
      end join_none
    end
  endtask
endclass

module top;
  descendant_if left_if(), right_if();
  descendant_cfg left_cfg, right_cfg;
  recursive_watcher watcher;
  initial begin
    left_cfg = new; right_cfg = new; watcher = new;
    left_cfg.vif = left_if; right_cfg.vif = right_if;
    watcher.descend(2, left_cfg);
    watcher.descend(2, right_cfg);
    #1; left_if.value = 2'b10; right_if.value = 2'b10; #1;
    if (left_cfg.hits != 1 || right_cfg.hits != 1)
      $fatal(1, "recursive identity failed left=%0d right=%0d",
             left_cfg.hits, right_cfg.hits);
    $display("PASS descendant recursive identity left=%0d right=%0d",
             left_cfg.hits, right_cfg.hits);
  end
endmodule
