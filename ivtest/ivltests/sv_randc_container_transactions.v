module test;
  class unconstrained_item;
    randc bit [1:0] dyn[];
    randc bit [1:0] que[$];
    function new;
      dyn = new[2];
      que = '{0, 0};
    endfunction
  endclass

  class constrained_item;
    randc bit [2:0] dyn[];
    randc bit [2:0] que[$];
    randc bit [2:0] assoc_i[int];
    bit fail;
    constraint sizes { dyn.size() == 2; que.size() == 2; }
    constraint domains {
      foreach (dyn[i]) dyn[i] inside {1, 3, 5};
      foreach (que[i]) que[i] inside {0, 2, 6};
      foreach (assoc_i[i]) assoc_i[i] inside {1, 4, 7};
      if (fail) dyn.size() == 7;
    }
    function new;
      dyn = new[2];
      que = '{0, 0};
      assoc_i[2] = 0;
      assoc_i[8] = 0;
    endfunction
  endclass

  class static_item;
    static randc bit [1:0] shared[];
    static function void initialize;
      shared = new[1];
      shared[0] = 0;
    endfunction
  endclass

  class copy_item;
    randc bit [1:0] dyn[];
    randc bit [1:0] que[$];
    randc bit [1:0] assoc_i[int];
    function new;
      dyn = new[1];
      que = '{0};
      assoc_i[5] = 0;
    endfunction
  endclass

  initial begin
    unconstrained_item plain;
    constrained_item constrained;
    static_item left;
    static_item right;
    copy_item original;
    copy_item copied;
    bit [3:0] plain_dyn[2];
    bit [3:0] plain_que[2];
    bit [7:0] constrained_dyn[2];
    bit [7:0] constrained_que[2];
    bit [7:0] constrained_assoc[2];
    bit [3:0] shared_mask;
    bit [3:0] original_mask;
    bit [3:0] copied_mask;
    bit [3:0] original_queue_mask;
    bit [3:0] copied_queue_mask;
    bit [3:0] original_assoc_mask;
    bit [3:0] copied_assoc_mask;
    bit [2:0] saved_dyn[2];
    bit [2:0] saved_que[2];
    bit [2:0] saved_assoc[2];

    plain = new;
    repeat (4) begin
      if (!plain.randomize()) $fatal(1, "unconstrained randomize failed");
      plain_dyn[0][plain.dyn[0]] = 1;
      plain_dyn[1][plain.dyn[1]] = 1;
      plain_que[0][plain.que[0]] = 1;
      plain_que[1][plain.que[1]] = 1;
    end
    if (plain_dyn[0] != 4'hf || plain_dyn[1] != 4'hf
        || plain_que[0] != 4'hf || plain_que[1] != 4'hf)
      $fatal(1, "unconstrained container cycles failed");

    constrained = new;
    repeat (3) begin
      if (!constrained.randomize()) $fatal(1, "constrained cycle failed");
      constrained_dyn[0][constrained.dyn[0]] = 1;
      constrained_dyn[1][constrained.dyn[1]] = 1;
      constrained_que[0][constrained.que[0]] = 1;
      constrained_que[1][constrained.que[1]] = 1;
      constrained_assoc[0][constrained.assoc_i[2]] = 1;
      constrained_assoc[1][constrained.assoc_i[8]] = 1;
    end
    if (constrained_dyn[0] != 8'b00101010
        || constrained_dyn[1] != 8'b00101010
        || constrained_que[0] != 8'b01000101
        || constrained_que[1] != 8'b01000101
        || constrained_assoc[0] != 8'b10010010
        || constrained_assoc[1] != 8'b10010010)
      $fatal(1, "constrained feasible cycles failed");
    saved_dyn[0] = constrained.dyn[0];
    saved_dyn[1] = constrained.dyn[1];
    saved_que[0] = constrained.que[0];
    saved_que[1] = constrained.que[1];
    saved_assoc[0] = constrained.assoc_i[2];
    saved_assoc[1] = constrained.assoc_i[8];
    constrained.fail = 1;
    if (constrained.randomize()) $fatal(1, "contradiction succeeded");
    if (constrained.dyn[0] != saved_dyn[0]
        || constrained.dyn[1] != saved_dyn[1]
        || constrained.que[0] != saved_que[0]
        || constrained.que[1] != saved_que[1]
        || constrained.assoc_i[2] != saved_assoc[0]
        || constrained.assoc_i[8] != saved_assoc[1])
      $fatal(1, "failed solve changed container values");
    constrained.fail = 0;
    constrained_dyn[0] = 0;
    constrained_dyn[1] = 0;
    constrained_que[0] = 0;
    constrained_que[1] = 0;
    constrained_assoc[0] = 0;
    constrained_assoc[1] = 0;
    repeat (3) begin
      if (!constrained.randomize()) $fatal(1, "post-rollback cycle failed");
      constrained_dyn[0][constrained.dyn[0]] = 1;
      constrained_dyn[1][constrained.dyn[1]] = 1;
      constrained_que[0][constrained.que[0]] = 1;
      constrained_que[1][constrained.que[1]] = 1;
      constrained_assoc[0][constrained.assoc_i[2]] = 1;
      constrained_assoc[1][constrained.assoc_i[8]] = 1;
    end
    if (constrained_dyn[0] != 8'b00101010
        || constrained_dyn[1] != 8'b00101010
        || constrained_que[0] != 8'b01000101
        || constrained_que[1] != 8'b01000101
        || constrained_assoc[0] != 8'b10010010
        || constrained_assoc[1] != 8'b10010010)
      $fatal(1, "failed solve consumed constrained history: %h %h %h %h %h %h",
             constrained_dyn[0], constrained_dyn[1],
             constrained_que[0], constrained_que[1],
             constrained_assoc[0], constrained_assoc[1]);

    static_item::initialize();
    left = new;
    right = new;
    repeat (2) begin
      if (!left.randomize()) $fatal(1, "left static randomize failed");
      shared_mask[static_item::shared[0]] = 1;
      if (!right.randomize()) $fatal(1, "right static randomize failed");
      shared_mask[static_item::shared[0]] = 1;
    end
    if (shared_mask != 4'hf)
      $fatal(1, "static receiver aliases forked container history");

    original = new;
    repeat (2) begin
      if (!original.randomize()) $fatal(1, "copy warmup failed");
      original_mask[original.dyn[0]] = 1;
      original_queue_mask[original.que[0]] = 1;
      original_assoc_mask[original.assoc_i[5]] = 1;
    end
    copied = new original;
    repeat (2) begin
      if (!copied.randomize()) $fatal(1, "copied state randomize failed");
      copied_mask[copied.dyn[0]] = 1;
      copied_queue_mask[copied.que[0]] = 1;
      copied_assoc_mask[copied.assoc_i[5]] = 1;
    end
    if ((original_mask | copied_mask) != 4'hf
        || (original_queue_mask | copied_queue_mask) != 4'hf
        || (original_assoc_mask | copied_assoc_mask) != 4'hf)
      $fatal(1, "class shallow copy lost container randc history");

    $display("PASSED");
  end
endmodule
