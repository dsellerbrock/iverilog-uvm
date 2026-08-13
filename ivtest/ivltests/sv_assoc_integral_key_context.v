module test;
  class object_key;
    int id;

    function new(int value);
      id = value;
    endfunction
  endclass

  class holder;
    string member_map[byte];
    int int_map[byte];
    real real_map[byte];
    int object_map[object_key];
    static string static_map[bit [7:0]];
  endclass

  class wrapper;
    holder nested;

    function new;
      nested = new;
    endfunction
  endclass

  string signed_map[byte];
  string unsigned_map[bit [7:0]];
  byte signed_key;
  bit [7:0] unsigned_key;
  int rc;
  holder h;
  wrapper w;
  object_key object_index;

  initial begin
    h = new;
    w = new;
    signed_map[1000] = "signed";
    if (!signed_map.exists(1000) || !signed_map.exists(8'he8)
        || signed_map[1000] != "signed"
        || signed_map[8'he8] != "signed") begin
      $display("FAILED: signed byte key was not context-converted");
      $finish;
    end

    rc = signed_map.first(signed_key);
    if (rc != 1 || signed_key !== 8'he8) begin
      $display("FAILED: first() returned rc=%0d key=%h", rc, signed_key);
      $finish;
    end
    if (signed_map.next(signed_key) != 0) begin
      $display("FAILED: next() did not recognize the converted key");
      $finish;
    end
    signed_map.delete(1000);
    if (signed_map.exists(8'he8)) begin
      $display("FAILED: delete() did not context-convert its key");
      $finish;
    end

    unsigned_map[-1] = "unsigned";
    if (!unsigned_map.exists(-1) || !unsigned_map.exists(8'hff)
        || unsigned_map[-1] != "unsigned"
        || unsigned_map[8'hff] != "unsigned") begin
      $display("FAILED: unsigned byte key was not context-converted");
      $finish;
    end
    rc = unsigned_map.first(unsigned_key);
    if (rc != 1 || unsigned_key !== 8'hff) begin
      $display("FAILED: unsigned first() returned rc=%0d key=%h",
               rc, unsigned_key);
      $finish;
    end

    h.member_map[1000] = "member";
    if (!h.member_map.exists(1000) || h.member_map[1000] != "member") begin
      $display("FAILED: class member key was not context-converted");
      $finish;
    end
    h.member_map.delete(1000);
    if (h.member_map.exists(8'he8)) begin
      $display("FAILED: class member delete() did not convert its key");
      $finish;
    end

    w.nested.member_map[1000] = "nested";
    w.nested.int_map[1000] = 32'h5a17c0de;
    w.nested.real_map[1000] = 3.25;
    if (!w.nested.member_map.exists(1000)
        || w.nested.member_map[1000] != "nested"
        || w.nested.int_map[1000] !== 32'h5a17c0de
        || w.nested.real_map[1000] != 3.25) begin
      $display("FAILED: nested typed member key was not context-converted");
      $finish;
    end

    object_index = new(17);
    w.nested.object_map[object_index] = 91;
    if (!w.nested.object_map.exists(object_index)
        || w.nested.object_map[object_index] != 91) begin
      $display("FAILED: nested object-key member lookup lost its receiver");
      $finish;
    end

    w.nested.member_map.delete(1000);
    w.nested.int_map.delete(1000);
    w.nested.real_map.delete(1000);
    w.nested.object_map.delete(object_index);
    if (w.nested.member_map.exists(8'he8)
        || w.nested.int_map.exists(8'he8)
        || w.nested.real_map.exists(8'he8)
        || w.nested.object_map.exists(object_index)) begin
      $display("FAILED: nested class member delete() did not convert its key");
      $finish;
    end

    holder::static_map[-1] = "static";
    if (!holder::static_map.exists(-1)
        || holder::static_map[-1] != "static") begin
      $display("FAILED: static class key was not context-converted");
      $finish;
    end

    $display("PASSED");
  end
endmodule
