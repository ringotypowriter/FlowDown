//
//  ContentView.swift
//  Scrubber
//
//  Created by 秋星桥 on 2/18/25.
//

import SwiftUI

struct ContentView: View {
    @State var searchQuery: String = ""
    @State var vm: ViewModel? = nil

    var body: some View {
        VStack(spacing: 16) {
            Text("ScrubberKit - Generate Search Report")
                .font(.title2)
                .bold()
                .fontDesign(.rounded)
            TextField("Search...", text: $searchQuery)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { begin() }
                .sheet(item: $vm) { item in
                    SearchProgressView(vm: item)
                }
                .frame(maxWidth: 500)
                .padding()
            Button {
                begin()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.largeTitle)
            }
            .buttonStyle(.plain)
            .underline()
            .disabled(searchQuery.isEmpty)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func begin() {
        let query = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        vm = ViewModel(query: query)
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 300)
}
