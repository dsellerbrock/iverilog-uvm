// IEEE 1800-2023 6.21: declaration lifetime overrides are per variable.
// They neither inherit from nor change the lifetime of sibling declarations.
module sv_mixed_lifetime_fixed_array_named_block;
  class payload;
    int value;
    function new(int value);
      this.value = value;
    endfunction
  endclass

  int fixed_ready;
  int fixed_ok[1:2];
  int named_ready;
  int named_observed[1:2];

  task static fixed_overlap(input int id);
    automatic int captured = id;
    automatic int ints[0:0];
    automatic logic [3:0] logics[0:0];
    automatic real reals[0:0];
    automatic string strings[0:0];
    automatic payload objects[0:0];

    ints[0] = captured + 10;
    logics[0] = captured;
    reals[0] = captured + 0.5;
    strings[0] = captured == 1 ? "one" : "two";
    objects[0] = new(captured + 40);

    if (captured == 1) begin
      fixed_ready = 1;
      #10;
    end else begin
      #1;
    end

    if (ints[0] == captured + 10 && logics[0] == captured
        && reals[0] == captured + 0.5
        && strings[0] == (captured == 1 ? "one" : "two")
        && objects[0] != null && objects[0].value == captured + 40)
      fixed_ok[captured] = 1;
    else
      $display("FAILED fixed call id=%0d int=%0d logic=%0d real=%0f string=%s object=%0d",
               captured, ints[0], logics[0], reals[0], strings[0],
               objects[0] == null ? -1 : objects[0].value);
  endtask

  task static named_overlap(input int id);
    begin : outer
      begin : inner
        automatic int captured = id;
        int shared;

        shared = id;
        if (captured == 1) begin
          named_ready = 1;
          #10;
        end else begin
          #1;
        end
        named_observed[captured] = shared;
      end
    end
  endtask

  task automatic static_fixed_arrays(output int value);
    static logic [3:0] logic_count[0:0] = '{default:0};
    static int int_count[0:0] = '{default:10};

    logic_count[0]++;
    int_count[0]++;
    value = logic_count[0] * 100 + int_count[0];
  endtask

  task automatic named_static(output int value);
    begin : outer
      begin : inner
        static int initialized_once = 40;
        automatic int invocation_value = initialized_once + 1;

        initialized_once = invocation_value;
        value = initialized_once;
      end
    end
  endtask

  initial begin
    int first;
    int second;

    fork
      fixed_overlap(1);
      begin
        wait (fixed_ready == 1);
        fixed_overlap(2);
      end
    join
    if (fixed_ok[1] !== 1 || fixed_ok[2] !== 1) begin
      $display("FAILED automatic fixed arrays ok=%0d,%0d",
               fixed_ok[1], fixed_ok[2]);
      $finish;
    end

    fork
      named_overlap(1);
      begin
        wait (named_ready == 1);
        named_overlap(2);
      end
    join
    if (named_observed[1] !== 2 || named_observed[2] !== 2) begin
      $display("FAILED named block shared=%0d,%0d",
               named_observed[1], named_observed[2]);
      $finish;
    end

    static_fixed_arrays(first);
    static_fixed_arrays(second);
    if (first !== 111 || second !== 212) begin
      $display("FAILED static fixed arrays=%0d,%0d", first, second);
      $finish;
    end

    named_static(first);
    named_static(second);
    if (first !== 41 || second !== 42) begin
      $display("FAILED named static initializer=%0d,%0d", first, second);
      $finish;
    end

    $display("PASSED");
  end
endmodule
