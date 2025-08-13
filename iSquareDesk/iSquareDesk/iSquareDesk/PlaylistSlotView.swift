import SwiftUI

struct PlaylistSlotView: View {
    @Binding var playlist: PlaylistData
    let slotIndex: Int
    let onLoadPlaylist: (Int) -> Void
    let onClearPlaylist: (Int) -> Void
    let onSelectItem: (PlaylistItem) -> Void

    var body: some View {
        VStack(spacing: 4) {
            header
//            tableHeader
            itemsList
        }
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text(playlist.name.isEmpty ? "Untitled Playlist" : playlist.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Menu {
                Button("Load Playlist…") { onLoadPlaylist(slotIndex) }
                Button("Clear Playlist") { onClearPlaylist(slotIndex) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    private var tableHeader: some View {
        HStack {
            Text("#").frame(width: 28, alignment: .trailing)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
    }

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(playlist.items) { item in
                    rowView(item: item)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
    }

    private func rowView(item: PlaylistItem) -> some View {
        Button(action: {
            print("PlaylistSlotView: slot=\(slotIndex) tapped item #\(item.index) title='\(item.title)' rel='\(item.relativePath)'")
            onSelectItem(item)
        }) {
            HStack {
                Text(String(item.index)).frame(width: 28, alignment: .trailing)
                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(item.index % 2 == 0 ? Color(hex: "#F5F5F7") : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
