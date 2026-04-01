module test;
  typedef enum logic [1:0] {
    ST_IDLE = 2'd0,
    ST_DONE = 2'd2
  } state_t;

  typedef struct {
    state_t state;
    string tag;
  } info_t;

  class holder_t;
    info_t info_by_id[int];
  endclass

  initial begin
    holder_t holder;

    holder = new;
    holder.info_by_id[3] = '{ST_DONE, "ok"};

    if (!holder.info_by_id.exists(3)) begin
      $display("FAILED: missing assoc entry");
      $finish(1);
    end

    if (holder.info_by_id[3].state != ST_DONE) begin
      $display("FAILED: wrong state %0d", holder.info_by_id[3].state);
      $finish(1);
    end

    if (holder.info_by_id[3].tag != "ok") begin
      $display("FAILED: wrong tag '%0s'", holder.info_by_id[3].tag);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
