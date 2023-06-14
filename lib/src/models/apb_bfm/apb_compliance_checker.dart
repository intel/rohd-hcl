
// Rules:
// - strobe must not be "active" during read transfer (all low during read)
// - the FSM is followed
// - addr, write, and wdata are valid when psel is asserted
// - slverr is not X during a transfer