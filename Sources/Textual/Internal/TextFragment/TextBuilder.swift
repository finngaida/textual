import SwiftUI

// MARK: - Overview
//
// TextBuilder constructs SwiftUI.Text from attributed content with inline attachments.
// It caches Text values keyed by attachment sizes to avoid unnecessary rebuilds during
// resize. When the container size changes, attachment sizes are recomputed and the cache
// is consulted. If the new sizes hash to the same key, the cached Text is reused.
//
// The cache key is derived from the hash of [AttachmentKey: CGSize]. Since attachment
// sizes often remain constant or repeat during incremental resize (e.g., window resizing),
// this compact key enables effective caching without storing the full proposal or
// attributed string. The cache has a count limit of 10 to prevent unbounded growth.
//
// Runs with attachments are converted to placeholder images sized by the attachment's
// sizeThatFits(_:in:) result. Placeholders are tagged with AttachmentAttribute so overlays
// can identify and render the actual attachment views at the resolved layout positions.

extension TextFragment {
  @MainActor @Observable final class TextBuilder {
    var text: Text

    @ObservationIgnored private let content: Content
    @ObservationIgnored private let cache: NSCache<KeyBox<AttachmentSizeCacheKey>, Box<Text>>

    init(_ content: Content, environment: TextEnvironmentValues) {
      let attachmentSizes = content.attachmentSizes(for: .unspecified, in: environment)

      self.text = Text(
        attributedString: content,
        attachmentSizes: attachmentSizes,
        in: environment
      )
      self.content = content
      self.cache = NSCache()
      self.cache.countLimit = 10

      self.cache.setObject(Box(self.text), forKey: KeyBox(AttachmentSizeCacheKey(attachmentSizes)))
    }

    func sizeChanged(_ size: CGSize, environment: TextEnvironmentValues) {
      let attachmentSizes = content.attachmentSizes(for: .init(size), in: environment)
      let cacheKey = KeyBox(AttachmentSizeCacheKey(attachmentSizes))

      if let text = cache.object(forKey: cacheKey) {
        self.text = text.wrappedValue
      } else {
        let text = Text(
          attributedString: content,
          attachmentSizes: attachmentSizes,
          in: environment
        )
        cache.setObject(Box(text), forKey: cacheKey)

        self.text = text
      }
    }
  }
}

extension Text {
  fileprivate init(
    attributedString: some AttributedStringProtocol,
    attachmentSizes: [AttachmentKey: CGSize],
    in environment: TextEnvironmentValues
  ) {
    let textValues = attributedString.runs.map { run in
      var text: Text

      var runEnvironment = environment
      runEnvironment.font = run.font ?? environment.font

      let key = run.textual.attachment.map {
        AttachmentKey(attachment: $0, font: runEnvironment.font)
      }

      #if TEXTUAL_ENABLE_ADVANCED_TEXT_LAYOUT
        if let key, let size = attachmentSizes[key] {
          // Create placeholder
          text = Text(placeholderSize: size)
            .baselineOffset(key.attachment.baselineOffset(in: runEnvironment))
            .customAttribute(
              AttachmentAttribute(
                key.attachment,
                presentationIntent: run.presentationIntent
              )
            )
        } else {
          text = Text(AttributedString(attributedString[run.range]))
        }
      #else
        if let key {
          text = Text(verbatim: key.attachment.description)
        } else {
          text = Text(AttributedString(attributedString[run.range]))
        }
      #endif

      #if TEXTUAL_ENABLE_LINKS && TEXTUAL_ENABLE_ADVANCED_TEXT_LAYOUT
        // Add link attribute for TextLinkInteraction
        if let link = run.link {
          text = text.customAttribute(LinkAttribute(link))
        }
      #endif

      return text
    }

    self = textValues.reduce(Text(verbatim: "")) { partialResult, text in
      Text("\(partialResult)\(text)")
    }
  }

  private init(placeholderSize size: CGSize) {
    self.init(SwiftUI.Image(size: size) { _ in })
  }
}

extension AttributedStringProtocol {
  fileprivate func attachmentSizes(
    for proposal: ProposedViewSize, in environment: TextEnvironmentValues
  ) -> [AttachmentKey: CGSize] {
    Dictionary(
      self.runs.compactMap { run in
        guard let attachment = run.textual.attachment else {
          return nil
        }
        var environment = environment
        environment.font = run.font ?? environment.font
        return (
          AttachmentKey(
            attachment: attachment,
            font: environment.font
          ),
          attachment.sizeThatFits(proposal, in: environment)
        )
      },
      uniquingKeysWith: { existing, _ in existing }
    )
  }
}

private struct AttachmentKey: Hashable {
  let attachment: AnyAttachment
  let font: Font?
}

private struct AttachmentSizeCacheKey: Hashable {
  private let entries: [Entry]

  init(_ sizes: [AttachmentKey: CGSize]) {
    self.entries = sizes.map { Entry(key: $0.key, size: $0.value) }
      .sorted { $0.sortKey < $1.sortKey }
  }

  private struct Entry: Hashable {
    let key: AttachmentKey
    let size: SizeKey
    let sortKey: String

    init(key: AttachmentKey, size: CGSize) {
      self.key = key
      self.size = SizeKey(size)
      self.sortKey = "\(String(reflecting: key.attachment))|\(String(reflecting: key.font))"
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.key == rhs.key && lhs.size == rhs.size
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(size)
    }
  }

  private struct SizeKey: Hashable {
    let widthBits: UInt64
    let heightBits: UInt64

    init(_ size: CGSize) {
      self.widthBits = Double(size.width).bitPattern
      self.heightBits = Double(size.height).bitPattern
    }
  }
}
