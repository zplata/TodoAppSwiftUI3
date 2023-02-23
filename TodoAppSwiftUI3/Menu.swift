//
//  Menu.swift
//  TodoAppSwiftUI3
//
//  Created by Roman Luzgin on 27.06.21.
//

import SwiftUI

struct Menu: View {
    @State private var menuOpen = false
    
    var body: some View {
        MainScreen(menuOpen: $menuOpen)
            .scaleEffect(menuOpen ? 0.5 : 1)
            .offset(x: menuOpen ? 160 : 0)
    }
}

struct Menu_Previews: PreviewProvider {
    static var previews: some View {
        Menu()
    }
}
