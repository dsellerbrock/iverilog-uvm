module test;
  typedef enum logic [1:0] {
    KIND_A = 2'd1,
    KIND_B = 2'd2
  } kind_t;

  typedef struct {
    kind_t kind;
    string name;
  } item_t;

  function automatic kind_t mk_kind();
    mk_kind = KIND_B;
  endfunction

  function automatic string mk_name();
    mk_name = {"hel", "lo"};
  endfunction

  class holder_t;
    item_t item;
  endclass

  initial begin
    holder_t holder;

    holder = new;
    holder.item.kind = mk_kind();
    holder.item.name = mk_name();

    if (holder.item.kind !== KIND_B) begin
      $display("FAILED: wrong kind %0d", holder.item.kind);
      $finish(1);
    end

    if (holder.item.name != "hello") begin
      $display("FAILED: wrong name '%0s'", holder.item.name);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
