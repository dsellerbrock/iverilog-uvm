module test;
  typedef enum logic [1:0] {
    ST_IDLE = 2'd0,
    ST_DONE = 2'd2
  } state_t;

  typedef struct {
    state_t state;
    string tag;
  } info_t;

  initial begin
    info_t info_by_idx [0:1];

    info_by_idx = '{'{ST_IDLE, "a"}, '{ST_DONE, "b"}};

    if (info_by_idx[0].state != ST_IDLE) begin
      $display("FAILED: wrong state0 %0d", info_by_idx[0].state);
      $finish(1);
    end

    if (info_by_idx[0].tag != "a") begin
      $display("FAILED: wrong tag0 '%0s'", info_by_idx[0].tag);
      $finish(1);
    end

    if (info_by_idx[1].state != ST_DONE) begin
      $display("FAILED: wrong state1 %0d", info_by_idx[1].state);
      $finish(1);
    end

    if (info_by_idx[1].tag != "b") begin
      $display("FAILED: wrong tag1 '%0s'", info_by_idx[1].tag);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
