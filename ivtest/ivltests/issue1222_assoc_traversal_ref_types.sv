// IEEE 1800-2017/2023 7.9.8: a traversal argument need only be assignment
// compatible with the index type. A narrower integral argument makes the
// method return -1 and receives the truncated index.
module issue1222_assoc_traversal_ref_types;
  int wide_vals[byte];
  string narrow_vals[int];
  int empty_vals[int];
  int wide_ix;
  byte narrow_ix;
  int status;
  bit ok = 1;

  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    wide_vals[byte'(-3)] = 30;
    wide_vals[byte'(5)] = 50;
    status = wide_vals.first(wide_ix);
    check(status == 1 && wide_ix == -3, "wider ref first");
    status = wide_vals.next(wide_ix);
    check(status == 1 && wide_ix == 5, "wider ref next");

    narrow_vals[1000] = "a";
    narrow_vals[2000] = "b";
    status = narrow_vals.first(narrow_ix);
    check(status == -1 && narrow_ix == 8'hE8, "narrower ref first truncates");
    status = narrow_vals.last(narrow_ix);
    check(status == -1 && narrow_ix == 8'hD0, "narrower ref last truncates");
    narrow_ix = 8'hE8;   // byte is signed: -24; the next index after -24 is 1000
    status = narrow_vals.next(narrow_ix);
    check(status == -1 && narrow_ix == 8'hE8, "narrower ref next");
    status = narrow_vals.prev(narrow_ix);
    check(status == 0, "narrower ref prev with nothing before -24");
    status = empty_vals.first(narrow_ix);
    check(status == 0, "empty array returns 0");

    if (ok) $display("PASSED");
  end
endmodule
