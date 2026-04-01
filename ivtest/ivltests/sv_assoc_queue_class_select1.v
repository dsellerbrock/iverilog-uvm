package sv_assoc_queue_class_select1_pkg;
  class item_t;
    int value;

    function new(int v);
      value = v;
    endfunction
  endclass

  typedef item_t item_q_t[$];
endpackage

module test;
  sv_assoc_queue_class_select1_pkg::item_q_t q_by_key[int];

  initial begin
    sv_assoc_queue_class_select1_pkg::item_t got;
    sv_assoc_queue_class_select1_pkg::item_t tmp;

    tmp = new(11);
    q_by_key[7].push_back(tmp);
    tmp = new(22);
    q_by_key[7].push_back(tmp);

    got = q_by_key[7][1];

    if (got == null) begin
      $display("FAIL: null");
      $finish(1);
    end

    if (got.value !== 22) begin
      $display("FAIL: value=%0d", got.value);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
