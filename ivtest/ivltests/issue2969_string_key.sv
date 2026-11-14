class item;
  rand byte a[string];
  function new();
    a["left"] = 0; a["right"] = 0; a[""] = 0;
    a["a long string key"] = 0; a["a\nkey"] = 0;
  endfunction
  constraint c {
    foreach (a[key]) {
      if (key == "left") a[key] == 3;
      else if ("" == key) a[key] == 4;
      else if (key == "a\nkey") a[key] == 5;
      else if (key != "a long string key") a[key] == 7;
      else a[key] == 9;
    }
  }
endclass
module top;
  item o;
  initial begin
    o = new;
    repeat (2) begin
      o.a["right"] = 0;
      if (!o.randomize() || o.a["left"] != 3 || o.a["right"] != 7 ||
          o.a[""] != 4 || o.a["a\nkey"] != 5 || o.a["a long string key"] != 9)
        $fatal(1, "string index mismatch");
      o.a.delete("right");
      o.a["another"] = 0;
      if (!o.randomize() || o.a["another"] != 7)
        $fatal(1, "changed string keys mismatch");
    end
    $display("PASS string associative index type");
    $finish(0);
  end
endmodule
