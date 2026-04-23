#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct LineReader {
  private var history: [String] = []
  private var originalTermios = termios()
  private let isTTY: Bool

  init() {
    isTTY = isatty(STDIN_FILENO) != 0
    if isTTY {
      tcgetattr(STDIN_FILENO, &originalTermios)
    }
  }

  mutating func readLine(prompt: String) -> String? {
    if !isTTY {
      Swift.print(prompt, terminator: "")
      return Swift.readLine()
    }
    return readLineRaw(prompt: prompt)
  }

  // MARK: - Raw mode line editing

  private mutating func readLineRaw(prompt: String) -> String? {
    enableRawMode()
    defer { disableRawMode() }

    output(prompt)

    var buf: [Character] = []
    var cursor = 0
    var histIdx = history.count
    var saved: [Character] = []

    while true {
      guard let b = readByte() else { return nil }

      switch b {
      case 0x0d, 0x0a: // Enter
        output("\r\n")
        let line = String(buf)
        if !line.isEmpty { history.append(line) }
        return line

      case 0x04: // Ctrl-D
        if buf.isEmpty { output("\r\n"); return nil }

      case 0x03: // Ctrl-C
        output("^C\r\n" + prompt)
        buf.removeAll(); cursor = 0
        histIdx = history.count; saved = []

      case 0x01: // Ctrl-A
        cursor = 0
        redraw(prompt, buf, cursor)

      case 0x05: // Ctrl-E
        cursor = buf.count
        redraw(prompt, buf, cursor)

      case 0x02: // Ctrl-B (back)
        if cursor > 0 { cursor -= 1; output("\u{1b}[D") }

      case 0x06: // Ctrl-F (forward)
        if cursor < buf.count { cursor += 1; output("\u{1b}[C") }

      case 0x10: // Ctrl-P (previous)
        historyBack(prompt: prompt, buf: &buf, cursor: &cursor,
                    histIdx: &histIdx, saved: &saved)

      case 0x0e: // Ctrl-N (next)
        historyForward(prompt: prompt, buf: &buf, cursor: &cursor,
                       histIdx: &histIdx, saved: &saved)

      case 0x15: // Ctrl-U
        buf.removeAll(); cursor = 0
        redraw(prompt, buf, cursor)

      case 0x7f, 0x08: // Backspace
        if cursor > 0 {
          cursor -= 1; buf.remove(at: cursor)
          redraw(prompt, buf, cursor)
        }

      case 0x1b: // ESC sequence
        handleEscape(prompt: prompt, buf: &buf, cursor: &cursor,
                     histIdx: &histIdx, saved: &saved)

      case 0x20...0x7e: // Printable ASCII
        buf.insert(Character(UnicodeScalar(b)), at: cursor)
        cursor += 1
        if cursor == buf.count {
          output(String(UnicodeScalar(b)))
        } else {
          redraw(prompt, buf, cursor)
        }

      default:
        break
      }
    }
  }

  private mutating func handleEscape(
    prompt: String,
    buf: inout [Character], cursor: inout Int,
    histIdx: inout Int, saved: inout [Character]
  ) {
    guard let b1 = readByte(), b1 == 0x5b,  // [
          let code = readByte() else { return }

    switch code {
    case 0x41: // Up
      historyBack(prompt: prompt, buf: &buf, cursor: &cursor,
                  histIdx: &histIdx, saved: &saved)
    case 0x42: // Down
      historyForward(prompt: prompt, buf: &buf, cursor: &cursor,
                     histIdx: &histIdx, saved: &saved)
    case 0x43: // Right
      if cursor < buf.count { cursor += 1; output("\u{1b}[C") }
    case 0x44: // Left
      if cursor > 0 { cursor -= 1; output("\u{1b}[D") }
    case 0x48: // Home
      cursor = 0; redraw(prompt, buf, cursor)
    case 0x46: // End
      cursor = buf.count; redraw(prompt, buf, cursor)
    case 0x33: // Delete (ESC [ 3 ~)
      if readByte() == 0x7e, cursor < buf.count {
        buf.remove(at: cursor)
        redraw(prompt, buf, cursor)
      }
    default:
      break
    }
  }

  // MARK: - History

  private func historyBack(
    prompt: String,
    buf: inout [Character], cursor: inout Int,
    histIdx: inout Int, saved: inout [Character]
  ) {
    if histIdx > 0 {
      if histIdx == history.count { saved = buf }
      histIdx -= 1
      buf = Array(history[histIdx]); cursor = buf.count
      redraw(prompt, buf, cursor)
    }
  }

  private func historyForward(
    prompt: String,
    buf: inout [Character], cursor: inout Int,
    histIdx: inout Int, saved: inout [Character]
  ) {
    if histIdx < history.count {
      histIdx += 1
      buf = histIdx == history.count ? saved : Array(history[histIdx])
      cursor = buf.count
      redraw(prompt, buf, cursor)
    }
  }

  // MARK: - Terminal

  private func enableRawMode() {
    var raw = originalTermios
    raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
    raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
    withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
      let cc = UnsafeMutableRawPointer(ptr)
        .assumingMemoryBound(to: cc_t.self)
      cc[Int(VMIN)] = 1
      cc[Int(VTIME)] = 0
    }
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
  }

  private func disableRawMode() {
    var t = originalTermios
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &t)
  }

  private func readByte() -> UInt8? {
    var b: UInt8 = 0
    return read(STDIN_FILENO, &b, 1) == 1 ? b : nil
  }

  private func output(_ s: String) {
    var s = s
    s.withUTF8 { buf in
      guard let p = buf.baseAddress else { return }
      _ = write(STDOUT_FILENO, p, buf.count)
    }
  }

  private func redraw(
    _ prompt: String, _ buf: [Character], _ cursor: Int
  ) {
    var s = "\r" + prompt + String(buf) + "\u{1b}[K"
    let back = buf.count - cursor
    if back > 0 { s += "\u{1b}[\(back)D" }
    output(s)
  }
}
