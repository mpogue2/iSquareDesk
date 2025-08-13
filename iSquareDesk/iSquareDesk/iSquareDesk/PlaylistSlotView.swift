/*****************************************************************************
**
** Copyright (C) 2025 Mike Pogue, Dan Lyke
** Contact: mpogue @ zenstarstudio.com
**
** This file is part of the iSquareDesk application.
**
** $ISQUAREDESK_BEGIN_LICENSE$
**
** Commercial License Usage
** For commercial licensing terms and conditions, contact the authors via the
** email address above.
**
** GNU General Public License Usage
** This file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appear in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file.
**
** $ISQUAREDESK_END_LICENSE$
**
****************************************************************************/
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
            Text("#").frame(width: 19, alignment: .center)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13))
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
        let color = colorForItem(item)
        return Button(action: {
            print("PlaylistSlotView: slot=\(slotIndex) tapped item #\(item.index) title='\(item.title)' rel='\(item.relativePath)'")
            onSelectItem(item)
        }) {
            HStack {
                Text(String(item.index)).frame(width: 19, alignment: .center)
                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 15))
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(item.index % 2 == 0 ? Color(hex: "#F5F5F7") : Color.clear)
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    private func colorForItem(_ item: PlaylistItem) -> Color {
        var rel = item.relativePath
        if rel.hasPrefix("/") { rel.removeFirst() }
        let type = rel.split(separator: "/").first.map { String($0).lowercased() } ?? ""
        switch type {
        case "patter":
            return Color(hex: "#7963FF")
        case "singing":
            return Color(hex: "#00AF5C")
        case "xtras":
            return Color(hex: "#9C1F00")
        case "vocals":
            return Color(hex: "#AB6900")
        default:
            return Color(hex: "#9C1F00")
        }
    }
}
