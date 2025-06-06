//
//  LiveMemPoolWidgetBundle.swift
//  LiveMemPoolWidget
//
//  Created by Abe Mangona on 5/14/25.
//

import WidgetKit
import SwiftUI

@main
struct LiveMemPoolWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveMemPoolWidget()
        LiveMemPoolWidgetControl()
        LiveMemPoolWidgetLiveActivity()
    }
}
