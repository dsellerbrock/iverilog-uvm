// Leave both the modport item and its complete task prototype pending at EOF.
// The next physical source file must start with clean parser-side state.
interface poisoned_file_if;
  task invoke(input int value); endtask

  modport broken(import task invoke(input int value)
