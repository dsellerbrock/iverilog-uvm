class inside_wide_item;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {32'd130}) == 1;
  }
endclass

class inside_mixed_item;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {8'd2, 32'd131}) == 0;
  }
endclass

class inside_range_item;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {[8'd2:32'd130]}) == 1;
  }
endclass

class inside_signed_item;
  rand bit signed [7:0] raw;
  constraint c {
    raw == 8'sh80;
    int'((raw >>> 1) inside {8'shc0, 32'd0}) == 0;
  }
endclass

class inside_narrow_item;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {8'd2, 8'd3}) == 1;
  }
endclass

class inside_container_item;
  bit [31:0] values[$];
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {8'd2, values}) == 0;
  }
endclass

class inside_negative_item;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c {
    a == 8'd250;
    b == 8'd10;
    int'(((a + b) / 8'd2) inside {8'd2, 32'd131}) == 1;
  }
endclass

module sv_constraint_cast_inside_global_common;
  bit [31:0] empty_values[$];
  bit [7:0] scope_a;
  bit [7:0] scope_b;
  inside_wide_item wide_item;
  inside_mixed_item mixed_item;
  inside_range_item range_item;
  inside_signed_item signed_item;
  inside_narrow_item narrow_item;
  inside_container_item container_item;
  inside_negative_item negative_item;
  int negative_ok;
  int scope_ok;

  initial begin
    wide_item = new;
    mixed_item = new;
    range_item = new;
    signed_item = new;
    narrow_item = new;
    container_item = new;
    negative_item = new;
    container_item.values.push_back(32'd131);
    negative_item.a = 8'd9;
    negative_item.b = 8'd11;
    if (!wide_item.randomize()) $fatal(1, "wide member common context failed");
    if (!mixed_item.randomize()) $fatal(1, "mixed member common context failed");
    if (!range_item.randomize()) $fatal(1, "range endpoint common context failed");
    if (!signed_item.randomize()) $fatal(1, "global unsigned context failed");
    if (!narrow_item.randomize()) $fatal(1, "narrow common context failed");
    if (!container_item.randomize())
      $fatal(1, "container declared element type omitted from common context");
    scope_ok = std::randomize(scope_a, scope_b) with {
      scope_a == 8'd250;
      scope_b == 8'd10;
      int'(((scope_a + scope_b) / 8'd2)
           inside {8'd2, empty_values}) == 0;
    };
    if (scope_ok != 1)
      $fatal(1, "empty container lost its declared element type");
    negative_ok = negative_item.randomize();
    if (negative_ok != 0 || negative_item.a !== 8'd9 ||
        negative_item.b !== 8'd11)
      $fatal(1, "global-context contradiction did not roll back");
    $display("PASSED");
    $finish(0);
  end
endmodule
