import AppKit

/// Writes project names over Mission Control's Spaces bar, so the Spaces can be
/// told apart while dragging them into a new order.
///
/// Mission Control announces neither opening nor closing, so the window list is
/// polled: slowly while it is closed, and fast enough while it is open for the
/// labels to follow thumbnails as they are dragged. Each display's bar gets one
/// panel covering it. Collapsed, the panel covers Apple's captions with a row of
/// its own and switches Space on a click. Expanded, it covers only the caption
/// under each project's thumbnail and lets every click through, so the
/// thumbnails can still be dragged.
@MainActor
final class MissionControlLabels {
  private static let closedInterval: TimeInterval = 0.25
  private static let openInterval: TimeInterval = 1.0 / 30

  private let state: AppState
  private var timer: Timer?
  private var interval: TimeInterval = 0
  private var panels: [BarPanel] = []
  /// Read when Mission Control opens, and again whenever the thumbnail windows
  /// change: a Space added or removed, or thumbnails rebuilt after a drop, leave
  /// the Spaces in a different order from the labels read before.
  private var labels: [MissionControlLabel]?
  private var thumbnailIDs: Set<Int> = []
  /// Per bar, keyed by the bar's origin, which does not move as it expands.
  private var slots: [String: [Int: Int]] = [:]
  /// A Space clicked in a collapsed bar. Mission Control is closed first, and the
  /// switch waits until it has gone, since the Space shortcut does nothing while
  /// Mission Control is on screen.
  private var pendingSwitch: Space?

  init(state: AppState) {
    self.state = state
  }

  func start() {
    schedule(Self.closedInterval)
  }

  private func schedule(_ newInterval: TimeInterval) {
    guard newInterval != interval else { return }
    interval = newInterval
    timer?.invalidate()
    let timer = Timer(timeInterval: newInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func tick() {
    let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let bars = MissionControlLayout.bars(in: infos)
    guard !bars.isEmpty else {
      closed()
      return
    }
    schedule(Self.openInterval)
    let ids = Set(bars.flatMap { $0.thumbnails.map(\.windowID) })
    if self.labels == nil || ids != thumbnailIDs {
      self.labels = state.missionControlLabels()
      thumbnailIDs = ids
    }
    let labels = self.labels ?? []
    while panels.count < bars.count {
      panels.append(BarPanel { [weak self] space in self?.select(space) })
    }
    for (panel, bar) in zip(panels, bars) {
      panel.show(content(for: bar, labels: labels), over: bar.frame)
    }
    for panel in panels.dropFirst(bars.count) { panel.hide() }
  }

  private func content(for bar: MissionControlBar, labels: [MissionControlLabel]) -> BarContent {
    let key = "\(bar.frame.minX),\(bar.frame.minY)"
    if bar.thumbnails.isEmpty {
      slots[key] = nil
      let cells = MissionControlLayout.cells(across: bar.frame, count: labels.count)
      return .collapsed(zip(labels, cells).map { ($0, $1) })
    }
    // A thumbnail count that differs from the Spaces, even after the labels are
    // read again, leaves no way to tell which thumbnail is which, so the captions
    // are left as they are.
    guard bar.thumbnails.count == labels.count else { return .expanded([]) }
    let slots = MissionControlLayout.slots(for: bar.thumbnails, keeping: self.slots[key] ?? [:])
    self.slots[key] = slots
    return .expanded(
      bar.thumbnails.compactMap { thumbnail in
        guard let slot = slots[thumbnail.windowID] else { return nil }
        let label = labels[slot]
        return label.isProject ? (label, MissionControlLayout.caption(of: thumbnail.frame)) : nil
      })
  }

  private func closed() {
    for panel in panels { panel.hide() }
    labels = nil
    thumbnailIDs = []
    slots = [:]
    schedule(Self.closedInterval)
    if let space = pendingSwitch {
      pendingSwitch = nil
      state.switchTo(space)
    }
  }

  private func select(_ space: Space) {
    pendingSwitch = space
    SpaceSwitcher.post(KeyCombo(keyCode: 53))  // Escape closes Mission Control.
  }
}

private enum BarContent {
  /// Every Space, each in its own cell across the whole bar.
  case collapsed([(MissionControlLabel, CGRect)])
  /// The projects only, each over its thumbnail's caption.
  case expanded([(MissionControlLabel, CGRect)])
}

/// A borderless panel covering one Spaces bar. Its level is above WindowManager's
/// layer-19 shield, which is what lets it show over Mission Control at all.
@MainActor
private final class BarPanel {
  private let panel: NSPanel
  private let view: BarView

  init(onSelect: @escaping (Space) -> Void) {
    panel = NSPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    view = BarView(onSelect: onSelect)
    panel.contentView = view
  }

  /// `frame` and the rectangles in `content` are in window-list coordinates, with
  /// the origin at the top left of the primary display.
  func show(_ content: BarContent, over frame: CGRect) {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    panel.setFrame(
      NSRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height), display: false)
    view.update(content, origin: frame.origin)
    // Collapsed, the panel takes clicks to switch Space. Expanded, every click must
    // reach the thumbnails underneath, or they could not be dragged.
    if case .collapsed = content { panel.ignoresMouseEvents = false } else { panel.ignoresMouseEvents = true }
    if !panel.isVisible { panel.orderFrontRegardless() }
  }

  func hide() {
    if panel.isVisible { panel.orderOut(nil) }
  }
}

@MainActor
private final class BarView: NSView {
  /// Chosen so that the label shows in the Spaces bar's own colour, sRGB (0.222,
  /// 0.233, 0.261) in a screenshot, and covers Apple's caption without showing
  /// its edges. Mission Control shows a window over it lighter than its colour
  /// values, so the values were found by measuring two fills and interpolating.
  private static let barColor = NSColor(srgbRed: 0.168, green: 0.177, blue: 0.204, alpha: 1)
  /// Sizes that match Apple's caption widths in a screenshot.
  private static let collapsedFont = NSFont.systemFont(ofSize: 13)
  private static let expandedFont = NSFont.systemFont(ofSize: 11.5)

  private let onSelect: (Space) -> Void
  private var cells: [(MissionControlLabel, CGRect)] = []
  private var collapsed = false

  init(onSelect: @escaping (Space) -> Void) {
    self.onSelect = onSelect
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

  override var isFlipped: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  /// Converts the content's window-list rectangles into this view's flipped
  /// coordinates, whose origin is the bar's top left.
  func update(_ content: BarContent, origin: CGPoint) {
    let cells: [(MissionControlLabel, CGRect)]
    switch content {
    case .collapsed(let items):
      collapsed = true
      cells = items
    case .expanded(let items):
      collapsed = false
      cells = items
    }
    self.cells = cells.map { ($0, $1.offsetBy(dx: -origin.x, dy: -origin.y)) }
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    if collapsed {
      Self.barColor.setFill()
      bounds.fill()
    }
    for (label, cell) in cells {
      if !collapsed {
        Self.barColor.setFill()
        cell.fill()
      }
      let text = NSAttributedString(
        string: label.text,
        attributes: [
          .font: collapsed ? Self.collapsedFont : Self.expandedFont,
          .foregroundColor: NSColor.white.withAlphaComponent(0.85),
          .paragraphStyle: Self.centred,
        ])
      let height = text.size().height
      // Collapsed, Apple's captions sit in the top 42 pt of the 96 pt bar.
      let band = collapsed ? CGRect(x: cell.minX, y: cell.minY, width: cell.width, height: 42) : cell
      let line = CGRect(x: band.minX + 4, y: band.midY - height / 2, width: band.width - 8, height: height)
      if label.isCurrent {
        let width = min(text.size().width + 16, line.width + 8)
        NSColor.white.withAlphaComponent(0.2).setFill()
        NSBezierPath(
          roundedRect: CGRect(x: line.midX - width / 2, y: line.minY - 3, width: width, height: height + 6),
          xRadius: 6, yRadius: 6
        ).fill()
      }
      text.draw(with: line, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }
  }

  private static let centred: NSParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byTruncatingTail
    return style
  }()

  override func mouseDown(with event: NSEvent) {
    guard collapsed else { return }
    let point = convert(event.locationInWindow, from: nil)
    guard let (label, _) = cells.first(where: { $0.1.contains(point) }), let space = label.space else { return }
    onSelect(space)
  }
}
