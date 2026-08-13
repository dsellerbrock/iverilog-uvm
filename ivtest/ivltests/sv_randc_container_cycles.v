module test;
  class assoc_key;
    int id;
    function new(int value);
      id = value;
    endfunction
  endclass

  class container_item;
    randc bit [1:0] dyn[];
    randc bit [1:0] que[$];
    randc bit [1:0] assoc_i[int];
    randc bit [1:0] assoc_s[string];
    randc bit [1:0] assoc_o[assoc_key];
    assoc_key key_a;
    assoc_key key_b;
    int dyn_size = 2;
    int que_size = 2;

    constraint sizes {
      dyn.size() == dyn_size;
      que.size() == que_size;
    }

    function new;
      dyn = new[2];
      que = '{0, 0};
      assoc_i[3] = 0;
      assoc_i[9] = 0;
      assoc_s["left"] = 0;
      assoc_s["right"] = 0;
      key_a = new(1);
      key_b = new(2);
      assoc_o[key_a] = 0;
      assoc_o[key_b] = 0;
    endfunction
  endclass

  class assoc_reset_item;
    randc bit [1:0] values[int];
    function new;
      values[7] = 0;
    endfunction
  endclass

  class queue_sort_item;
    randc bit [1:0] values[$];
    function new;
      values = '{0, 0};
    endfunction
  endclass

  task automatic clear_masks(ref bit [3:0] masks[2]);
    masks[0] = 0;
    masks[1] = 0;
  endtask

  initial begin
    container_item base;
    container_item paused;
    container_item shifted;
    container_item resized;
    assoc_reset_item old_assoc;
    assoc_reset_item new_assoc;
    queue_sort_item sorted;
    bit [3:0] dm[2];
    bit [3:0] qm[2];
    bit [3:0] im[2];
    bit [3:0] sm[2];
    bit [3:0] om[2];
    bit [3:0] masks_pre[2];
    bit [3:0] masks_post[2];
    bit [3:0] inserted;
    bit [3:0] sort_pre[2];
    bit [3:0] sort_post[2];
    bit [1:0] held;
    string saved_state;

    base = new;
    clear_masks(dm);
    clear_masks(qm);
    clear_masks(im);
    clear_masks(sm);
    clear_masks(om);
    repeat (4) begin
      if (!base.randomize()) $fatal(1, "baseline randomize failed");
      dm[0][base.dyn[0]] = 1;
      dm[1][base.dyn[1]] = 1;
      qm[0][base.que[0]] = 1;
      qm[1][base.que[1]] = 1;
      im[0][base.assoc_i[3]] = 1;
      im[1][base.assoc_i[9]] = 1;
      sm[0][base.assoc_s["left"]] = 1;
      sm[1][base.assoc_s["right"]] = 1;
      om[0][base.assoc_o[base.key_a]] = 1;
      om[1][base.assoc_o[base.key_b]] = 1;
    end
    if (dm[0] != 4'hf || dm[1] != 4'hf
        || qm[0] != 4'hf || qm[1] != 4'hf
        || im[0] != 4'hf || im[1] != 4'hf
        || sm[0] != 4'hf || sm[1] != 4'hf
        || om[0] != 4'hf || om[1] != 4'hf)
      $fatal(1, "container elements did not form independent cycles");

    paused = new;
    clear_masks(masks_pre);
    repeat (2) begin
      if (!paused.randomize()) $fatal(1, "pause warmup failed");
      masks_pre[0][paused.dyn[0]] = 1;
      masks_pre[1][paused.dyn[1]] = 1;
    end
    held = paused.dyn[1];
    paused.dyn[1].rand_mode(0);
    repeat (2) begin
      if (!paused.randomize()) $fatal(1, "paused randomize failed");
      masks_pre[0][paused.dyn[0]] = 1;
      if (paused.dyn[1] != held)
        $fatal(1, "disabled dynamic element changed");
    end
    if (masks_pre[0] != 4'hf)
      $fatal(1, "enabled sibling did not complete its cycle");
    paused.dyn[1].rand_mode(1);
    repeat (2) begin
      if (!paused.randomize()) $fatal(1, "resume randomize failed");
      masks_pre[1][paused.dyn[1]] = 1;
    end
    if (masks_pre[1] != 4'hf)
      $fatal(1, "resumed element did not continue its prior cycle");

    shifted = new;
    clear_masks(masks_pre);
    clear_masks(masks_post);
    inserted = 0;
    repeat (2) begin
      if (!shifted.randomize()) $fatal(1, "queue warmup failed");
      masks_pre[0][shifted.que[0]] = 1;
      masks_pre[1][shifted.que[1]] = 1;
    end
    shifted.que.insert(0, 0);
    shifted.que_size = 3;
    repeat (2) begin
      if (!shifted.randomize()) $fatal(1, "queue shift failed");
      inserted[shifted.que[0]] = 1;
      masks_post[0][shifted.que[1]] = 1;
      masks_post[1][shifted.que[2]] = 1;
    end
    if ((masks_pre[0] | masks_post[0]) != 4'hf
        || (masks_pre[1] | masks_post[1]) != 4'hf)
      $fatal(1, "queue insertion did not move history with old elements");
    repeat (2) begin
      if (!shifted.randomize()) $fatal(1, "new queue element failed");
      inserted[shifted.que[0]] = 1;
    end
    if (inserted != 4'hf)
      $fatal(1, "inserted queue element did not start a fresh cycle");

    resized = new;
    clear_masks(masks_post);
    inserted = 0;
    repeat (2) begin
      if (!resized.randomize()) $fatal(1, "dynamic warmup failed");
    end
    resized.dyn_size = 3;
    resized.dyn = new[3](resized.dyn);
    repeat (4) begin
      if (!resized.randomize()) $fatal(1, "dynamic resize failed");
      masks_post[0][resized.dyn[0]] = 1;
      masks_post[1][resized.dyn[1]] = 1;
      inserted[resized.dyn[2]] = 1;
    end
    if (masks_post[0] != 4'hf || masks_post[1] != 4'hf
        || inserted != 4'hf)
      $fatal(1, "dynamic reallocation did not create fresh cycles");

    old_assoc = new;
    new_assoc = new;
    repeat (3)
      if (!old_assoc.randomize()) $fatal(1, "assoc warmup failed");
    saved_state = old_assoc.get_randstate();
    old_assoc.values.delete(7);
    old_assoc.values[7] = 0;
    new_assoc.set_randstate(saved_state);
    if (!old_assoc.randomize() || !new_assoc.randomize())
      $fatal(1, "assoc reset comparison failed");
    if (old_assoc.values[7] != new_assoc.values[7])
      $fatal(1, "associative delete/reinsert retained stale history");

    sorted = new;
    clear_masks(sort_pre);
    clear_masks(sort_post);
    repeat (2) begin
      if (!sorted.randomize()) $fatal(1, "queue sort warmup failed");
      sort_pre[0][sorted.values[0]] = 1;
      sort_pre[1][sorted.values[1]] = 1;
    end
    // Force a known source permutation without changing either element's
    // cycle state. sort() must carry that state with the same member.
    sorted.values[0] = 3;
    sorted.values[1] = 0;
    sorted.values.sort();
    repeat (2) begin
      if (!sorted.randomize()) $fatal(1, "queue sort continuation failed");
      sort_post[0][sorted.values[0]] = 1;
      sort_post[1][sorted.values[1]] = 1;
    end
    if ((sort_pre[1] | sort_post[0]) != 4'hf
        || (sort_pre[0] | sort_post[1]) != 4'hf)
      $fatal(1, "queue sort did not carry history with its permutation");

    $display("PASSED");
  end
endmodule
