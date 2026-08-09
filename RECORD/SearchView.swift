//
//  SearchView.swift
//  RECORD
//
//  Created by Amir Rashidov on 30.06.2026.
//

import Foundation
import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Song] = []
    @State private var searchTask: Task<Void, Never>?
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            Color.recordBG
                .ignoresSafeArea()
            
            VStack (alignment: .leading, spacing: 16) {
                
                Text("Find your record")
                    .font(.display(24, .bold))
                    .foregroundStyle(Color.recordText)
                
                // SEARCH FIELD
                TextField("", text: $query, prompt: Text("Search a song...").foregroundColor(.recordTertiary))
                    .font(.sans(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.recordSeparator)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.recordText)
                    .onChange(of: query) {
                        //cancel any in-flight search, then debounce
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            if Task .isCancelled { return }
                            results = await searchSongs(query: query)
                        }
                    }
                // RESULTS LIST
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(results) { song in
                            NavigationLink(value: song) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { image in image.resizable()
                                    } placeholder: {
                                        Color.recordSeparator
                                    }
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.trackName)
                                            .font(.sans(15, .medium))
                                            .foregroundStyle(Color.recordText)
                                            .lineLimit(1)
                                        Text(song.artistName)
                                            .font(.sans(13))
                                            .foregroundStyle(Color.recordSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
}
#Preview {
    NavigationStack {
        SearchView(path: .constant(NavigationPath()))
    }
}
