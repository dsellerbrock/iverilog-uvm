module sv_ustruct_member_defaults_edge;
  localparam integer BASE = 40;
  integer failures = 0;

  typedef struct {
    integer value = BASE + 2;
  } leaf_t;

  typedef struct {
    leaf_t leaf;
    integer tag = BASE + 3;
  } outer_t;

  function automatic integer shadowed_defaults_ok;
    localparam integer BASE = 1000;
    outer_t value;
    begin
      shadowed_defaults_ok =
            value.leaf.value == 42 && value.tag == 43;
    end
  endfunction

  function automatic integer next_static_value;
    localparam integer BASE = 2000;
    static outer_t state;
    begin
      next_static_value = state.leaf.value;
      state.leaf.value = state.leaf.value + 1;
    end
  endfunction

  initial begin
    integer first;
    integer second;

    #0;
    if (!shadowed_defaults_ok()) begin
      $display("FAILED defining-scope lookup");
      failures = failures + 1;
    end

    first = next_static_value();
    second = next_static_value();
    if (first != 42 || second != 43) begin
      $display("FAILED static initialization lifetime: %0d,%0d",
               first, second);
      failures = failures + 1;
    end

    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", failures);
    $finish(0);
  end
endmodule
