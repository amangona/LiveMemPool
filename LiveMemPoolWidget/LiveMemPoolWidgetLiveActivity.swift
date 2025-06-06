//
//  LiveMemPoolWidgetLiveActivity.swift
//  LiveMemPoolWidget
//
//  Created by Abe Mangona on 5/14/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveMemPoolWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiveMemPoolWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveMemPoolWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiveMemPoolWidgetAttributes {
    fileprivate static var preview: LiveMemPoolWidgetAttributes {
        LiveMemPoolWidgetAttributes(name: "World")
    }
}

extension LiveMemPoolWidgetAttributes.ContentState {
    fileprivate static var smiley: LiveMemPoolWidgetAttributes.ContentState {
        LiveMemPoolWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiveMemPoolWidgetAttributes.ContentState {
         LiveMemPoolWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiveMemPoolWidgetAttributes.preview) {
   LiveMemPoolWidgetLiveActivity()
} contentStates: {
    LiveMemPoolWidgetAttributes.ContentState.smiley
    LiveMemPoolWidgetAttributes.ContentState.starEyes
}
