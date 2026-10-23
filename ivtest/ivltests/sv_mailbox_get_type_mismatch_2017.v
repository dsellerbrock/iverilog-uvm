module sv_mailbox_get_type_mismatch;
  mailbox mb = new;
  int x = 0;
  initial begin
    mb.put("text");
    mb.get(x);
  end
endmodule
