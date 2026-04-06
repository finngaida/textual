import SwiftUI

#if TEXTUAL_ENABLE_LINKS && TEXTUAL_ENABLE_ADVANCED_TEXT_LAYOUT
  struct LinkAttribute: TextAttribute {
    var url: URL

    init(_ url: URL) {
      self.url = url
    }
  }

  extension Text.Layout.Run {
    var url: URL? {
      self[LinkAttribute.self]?.url
    }
  }
#endif
