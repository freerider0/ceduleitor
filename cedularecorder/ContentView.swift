//
//  ContentView.swift
//  cedularecorder
//
//  Created by Josep on 4/9/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // Use NavigationStack for iOS 16+ or NavigationView for iOS 15
        if #available(iOS 16.0, *) {
            NavigationStack {
                InspectionListView()
            }
        } else {
            NavigationView {
                InspectionListView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

#Preview {
    ContentView()
}