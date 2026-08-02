class dispatch_item;
  int value;
endclass

class dispatch_base #(type REQ = dispatch_item);
  REQ req;

  virtual function void randomize_req(REQ item, int idx);
    item.value = 1;
  endfunction

  task body;
    req = new;
    // IEEE 1800-2017 8.20: an unqualified virtual call uses this as the
    // receiver, so the dynamic type must select the most-derived override.
    randomize_req(req, 0);
  endtask
endclass

class dispatch_middle #(type REQ = dispatch_item) extends dispatch_base #(REQ);
  virtual function void randomize_req(REQ item, int idx);
    item.value = 2;
  endfunction
endclass

class dispatch_top extends dispatch_middle #(dispatch_item);
  virtual function void randomize_req(dispatch_item item, int idx);
    super.randomize_req(item, idx);
    item.value += 10;
  endfunction
endclass

module parameterized_implicit_virtual_dispatch_test;
  dispatch_top seq;
  initial begin
    seq = new;
    seq.body();
    if (seq.req == null || seq.req.value != 12) begin
      $error("implicit virtual dispatch used base method: value=%0d",
             seq.req == null ? -1 : seq.req.value);
      $finish_and_return(1);
    end
    $display("PASSED: parameterized implicit virtual dispatch");
    $finish;
  end
endmodule
