// IEEE 1800-2017/2023 §§7.2.2, 8.12, 9.3.2, 13.3; issue #434.
class issue434_tag;
  int id;
endclass

typedef struct {
  issue434_tag handle;
  int id;
} issue434_capture_t;

module issue434;
  int seen11;
  int seen22;

  task automatic launch(input issue434_capture_t rec);
    fork
      begin
        #1;
        if (rec.handle == null || rec.handle.id != rec.id)
          $fatal(1, "captured aggregate changed: id=%0d handle=%p", rec.id, rec.handle);
        if (rec.id == 11)
          seen11++;
        else if (rec.id == 22)
          seen22++;
        else
          $fatal(1, "unexpected captured id %0d", rec.id);
      end
    join_none
  endtask

  initial begin
    issue434_tag first, second;
    issue434_capture_t rec;
    first = new; first.id = 11;
    second = new; second.id = 22;
    rec.handle = first; rec.id = 11;
    launch(rec);
    rec.handle = second; rec.id = 22;
    launch(rec);
    rec.handle = null; rec.id = 99;
    #2;
    if (seen11 != 1 || seen22 != 1)
      $fatal(1, "captured aggregate counts %0d/%0d", seen11, seen22);
    $display("PASS: detached workers retained aggregate handles");
    $display("PASSED");
  end
endmodule
