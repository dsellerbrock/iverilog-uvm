// IEEE 1800-2017/2023 7.4, 7.8, 8.6, 13.5: OpenTitan Flash selects a
// backdoor-utility handle through an associative key and fixed bank slot.
typedef enum int { Data, Info } part_t;

class memory;
  int value;
  int writes;
  int reads;
  int task_calls;
  function new(int value); this.value = value; endfunction
  function void write(int offset, int data);
    value = data + offset;
    writes++;
  endfunction
  function int read(int offset);
    reads++;
    return value + offset;
  endfunction
  task bump(int delta);
    value += delta;
    task_calls++;
  endtask
endclass

class cfg;
  memory map[part_t][3:2];
  int key_calls;
  int slot_calls;

  function part_t key(); key_calls++; return Info; endfunction
  function int slot(); slot_calls++; return 2; endfunction
  function void update(part_t part, int bank, int data);
    map[part][bank].write(4, data);
  endfunction
  function int sample(part_t part, int bank);
    return map[part][bank].read(6);
  endfunction
  function void update_selected(int data);
    map[key()][slot()].write(7, data);
  endfunction
  function int sample_selected();
    return map[key()][slot()].read(8);
  endfunction
endclass

module top;
  cfg c;
  memory data2, data3, info2, info3;
  initial begin
    c = new;
    data2 = new(2);
    data3 = new(3);
    info2 = new(12);
    info3 = new(13);
    c.map[Data][2] = data2;
    c.map[Data][3] = data3;
    c.map[Info][2] = info2;
    c.map[Info][3] = info3;

    c.update(Info, 3, 10);
    if (info3.value != 14 || info3.writes != 1 || c.sample(Info, 3) != 20
        || info3.reads != 1)
      $fatal(1, "variable key and bank receiver");
    c.update_selected(20);
    if (info2.value != 27 || info2.writes != 1
        || c.key_calls != 1 || c.slot_calls != 1)
      $fatal(1, "selected void-function receiver or duplicate index evaluation");
    if (c.sample_selected() != 35 || info2.reads != 1
        || c.key_calls != 2 || c.slot_calls != 2)
      $fatal(1, "selected function receiver or duplicate index evaluation");
    if (data2.value != 2 || data2.writes != 0 || data3.value != 3
        || data3.writes != 0 || info3.value != 14)
      $fatal(1, "neighbor handle modified");

    c.map[c.key()][c.slot()].bump(5);
    if (info2.value != 32 || info2.task_calls != 1
        || c.key_calls != 3 || c.slot_calls != 3 || data2.value != 2)
      $fatal(1, "selected task receiver or duplicate index evaluation");

    data2.write(1, 5);
    if (data2.value != 6 || data2.read(2) != 8)
      $fatal(1, "ordinary class method call");
    $display("PASSED");
  end
endmodule
