//
//  AvatarView.swift
//  RECORD
//
//  Created by Amir Rashidov on 18.07.2026.
//

import Foundation
import SwiftUI

struct AvatarView: View {
    let username: String
    var size: CGFloat = 32
    
    // First letter, uppercased. Empty username → "?"
    private var initial: String {
        guard let first = username.first else { return "?"}
        return String(first).uppercased()
    }
    
    var body: some View {
        Circle()
            .fill(Color.recordGreen)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.sans(size * 0.45, .bold))
                    .foregroundStyle(.black)
            )
    }
}

#Preview {
    AvatarView(username: "AMIR", size: 40)
}
