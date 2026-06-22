//
//  ContentView.swift
//  RECORD
//
//  Created by Amir Rashidov on 20.06.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            //Full-screen dark background
            Color.recordBG
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                
                // HEADER: wordmark + nav
                HStack {
                    Text("RECORD")
                        .font(.title2)
                        .fontWeight(.bold)
                        .tracking(4)
                        .foregroundColor(.recordText)
                    Spacer()
                    Text("@amir")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Color.recordMuted)
                }
                
                // DATELINE
                HStack {
                    Text("THE DAILY EDITION")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color.recordDim)
                    Spacer()
                    Text("THU · 18 JUN 2026")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color.recordDim)
                }
                Rectangle()
                    .fill(Color.recordDim.opacity(0.3))
                    .frame(height: 1)
                
                // THE GREEN "POST" CARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR RECORD · TODAY")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color.recordGreen)
                    
                    Text("What are you playing today?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.recordText)
                    
                    Button {
                        // we'll wire this up later
                    } label: {
                        Text("Choose a song  →")
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.recordGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.recordSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Rectangle()
                        .fill(Color.recordGreen)
                        .frame(width: 4)
                    , alignment: .leading
                )
                
                // TODAY'S RECORDS heading
                HStack {
                    Text("TODAY'S RECORDS")
                        .font(.headline)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(Color.recordText)
                    Spacer()
                    Text("June 18")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.recordDim)
                }
                Rectangle()
                    .fill(Color.recordDim.opacity(0.3))
                    .frame(height: 1)
                        
                //EMPTY STATE
                VStack(spacing: 8) {
                    Text("00")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(Color.recordSurface)
                    Text("No records yet today.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.recordText)
                    Text("The edition fills as your friends drop their song. Post yours and be the first line.")
                        .font(.subheadline)
                        .foregroundStyle(Color.recordMuted)
                        .multilineTextAlignment(.center)
                    Text("ONE SONG · ONE DAY · RESETS 4AM")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color.recordDim)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                Spacer()
            }
            .padding(20)
        }
    }
}
#Preview {
    ContentView()
}

        
                
                
                
