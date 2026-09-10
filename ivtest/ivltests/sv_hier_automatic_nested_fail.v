// IEEE 1800-2017/2023 6.21: named intermediate scopes do not grant access.
module sv_hier_automatic_nested_fail;
  task automatic t();
    begin : inner
      int count;
      count = 0;
    end
  endtask
  initial $display("%0d", t.inner.count);
endmodule
