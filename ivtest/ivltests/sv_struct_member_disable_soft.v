// IEEE 1800-2017 18.5.14.1: a member leaf has a distinct disable-soft
// identity. Disabling record.a must retain record.b's soft preference, while
// disabling the outer record deliberately covers both descendant leaves.
typedef struct {
  rand bit [7:0] a;
  rand bit [7:0] b;
} disable_soft_record_t;

class targeted_disable_item;
  rand disable_soft_record_t record;
  constraint preferences {
    soft record.a == 8'd5;
    soft record.b == 8'd7;
  }
  constraint control {
    disable soft record.a;
    record.a inside {[8'd1:8'd20]};
    record.b inside {[8'd1:8'd20]};
  }
endclass

class outer_disable_item;
  rand disable_soft_record_t record;
  constraint preferences {
    soft record.a == 8'd5;
    soft record.b == 8'd7;
  }
  constraint control {
    disable soft record;
    record.a inside {[8'd1:8'd20]};
    record.b inside {[8'd1:8'd20]};
  }
endclass

module test;
  initial begin
    targeted_disable_item targeted;
    outer_disable_item outer;
    bit targeted_a_varied;
    bit outer_a_varied;
    bit outer_b_varied;

    targeted = new;
    outer = new;
    targeted.srandom(32'h18_05_14_01);
    outer.srandom(32'h18_05_14_02);
    repeat (30) begin
      if (targeted.randomize() !== 1)
        $fatal(1, "targeted disable-soft solve failed");
      if (targeted.record.b !== 8'd7)
        $fatal(1, "disable soft record.a also dropped record.b");
      if (targeted.record.a !== 8'd5)
        targeted_a_varied = 1'b1;

      if (outer.randomize() !== 1)
        $fatal(1, "outer-property disable-soft solve failed");
      if (outer.record.a !== 8'd5)
        outer_a_varied = 1'b1;
      if (outer.record.b !== 8'd7)
        outer_b_varied = 1'b1;
    end

    if (!targeted_a_varied)
      $fatal(1, "disable soft record.a retained its soft preference");
    if (!outer_a_varied || !outer_b_varied)
      $fatal(1, "disable soft record did not cover both member leaves");
    $display("PASSED");
  end
endmodule
