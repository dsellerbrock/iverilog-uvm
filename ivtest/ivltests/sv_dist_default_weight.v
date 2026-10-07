class default_weight_item;
  rand bit [3:0] value;
  constraint distribution_c { value dist {[2:3] :/ 3, default :/ 1}; }
endclass

class default_overlap_item;
  rand bit [3:0] value;
  constraint distribution_c {
    value dist {[2:4] :/ 2, [4:6] :/ 1, 8 :/ 0, default :/ 1};
  }
endclass

class default_excluded_value_item;
  rand bit [3:0] value;
  constraint distribution_c { value dist {8 :/ 0, default :/ 1}; }
  constraint fixed_c { value == 8; }
endclass

module test;
  default_weight_item item;
  default_overlap_item overlap;
  default_excluded_value_item excluded;
  int counts[16];
  int explicit_count, default_count, failures;

  initial begin
    for (int i = 0; i < 16; i++) counts[i] = 0;
    item = new;
    item.srandom(32'hd157_2023);
    repeat (4000) begin
      if (!item.randomize()) $fatal(1, "default dist randomize failed");
      counts[item.value]++;
      if (item.value inside {[2:3]}) explicit_count++;
      else default_count++;
    end
    if (explicit_count < 2700 || explicit_count > 3300
        || default_count < 700 || default_count > 1300) begin
      $display("FAIL aggregate weights explicit=%0d default=%0d",
               explicit_count, default_count);
      failures++;
    end
    if (counts[2] < 1250 || counts[2] > 1750
        || counts[3] < 1250 || counts[3] > 1750) begin
      $display("FAIL explicit interval uniformity %0d %0d", counts[2], counts[3]);
      failures++;
    end
    for (int i = 0; i < 16; i++) begin
      if (i != 2 && i != 3 && (counts[i] < 35 || counts[i] > 110)) begin
        $display("FAIL default complement uniformity value=%0d count=%0d", i, counts[i]);
        failures++;
      end
    end

    overlap = new;
    overlap.srandom(32'hd157_0a11);
    repeat (256) begin
      if (!overlap.randomize()) $fatal(1, "overlap/default randomize failed");
      if (overlap.value == 8) begin
        $display("FAIL zero-weight listed value entered the default complement");
        failures++;
      end
    end

    excluded = new;
    excluded.value = 8;
    if (excluded.randomize()) begin
      $display("FAIL zero-weight explicit value was made legal by default");
      failures++;
    end
    if (failures != 0) $fatal(1, "dist default checks failed: %0d", failures);
    $display("PASSED");
  end
endmodule
