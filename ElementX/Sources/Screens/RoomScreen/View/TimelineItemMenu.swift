//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

struct TimelineItemMenuActions {
    let actions: [TimelineItemMenuAction]
    let debugActions: [TimelineItemMenuAction]
    
    init?(actions: [TimelineItemMenuAction], debugActions: [TimelineItemMenuAction]) {
        if actions.isEmpty, debugActions.isEmpty {
            return nil
        }
        
        self.actions = actions
        self.debugActions = debugActions
    }
    
    var canReply: Bool {
        for action in actions {
            if case .reply = action {
                return true
            }
        }
        
        return false
    }
}

enum TimelineItemMenuAction: Identifiable, Hashable {
    case copy
    case edit
    case copyPermalink
    case redact
    case reply
    case forward(itemID: TimelineItemIdentifier)
    case viewSource
    case retryDecryption(sessionID: String)
    case report
    case react
    
    var id: Self { self }
    
    /// Whether the item should cancel a reply/edit occurring in the composer.
    var switchToDefaultComposer: Bool {
        switch self {
        case .reply, .edit:
            return false
        default:
            return true
        }
    }
    
    /// Whether the action should be shown for an item that failed to send.
    var canAppearInFailedEcho: Bool {
        switch self {
        case .copy, .edit, .redact, .viewSource:
            return true
        default:
            return false
        }
    }
    
    /// Whether the action should be shown for a redacted item.
    var canAppearInRedacted: Bool {
        switch self {
        case .viewSource:
            return true
        default:
            return false
        }
    }
    
    /// The item's label.
    var label: some View {
        switch self {
        case .copy: return Label(L10n.actionCopy, systemImage: "doc.on.doc")
        case .edit: return Label(L10n.actionEdit, systemImage: "pencil.line")
        case .copyPermalink: return Label(L10n.actionCopyLinkToMessage, systemImage: "link")
        case .reply: return Label(L10n.actionReply, systemImage: "arrowshape.turn.up.left")
        case .forward: return Label(L10n.actionForward, systemImage: "arrowshape.turn.up.right")
        case .redact: return Label(L10n.actionRemove, systemImage: "trash")
        case .viewSource: return Label(L10n.actionViewSource, systemImage: "doc.text.below.ecg")
        case .retryDecryption: return Label(L10n.actionRetryDecryption, systemImage: "arrow.down.message")
        case .report: return Label(L10n.actionReportContent, systemImage: "exclamationmark.bubble")
        case .react: return Label(L10n.actionReact, systemImage: "hand.thumbsup")
        }
    }
}

extension RoomTimelineItemProtocol {
    var isReactable: Bool {
        guard let eventItem = self as? EventBasedTimelineItemProtocol else { return false }
        return !eventItem.isRedacted && !eventItem.hasFailedToSend && !eventItem.hasFailedDecryption
    }
}

public struct TimelineItemMenu: View {
    @EnvironmentObject private var context: RoomScreenViewModel.Context
    @Environment(\.dismiss) private var dismiss
    
    let item: EventBasedTimelineItemProtocol
    let actions: TimelineItemMenuActions
    
    public var body: some View {
        VStack {
            header
                .frame(idealWidth: 300.0)
            
            Divider()
                .background(Color.compound.bgSubtlePrimary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0.0) {
                    if item.isReactable {
                        reactionsSection
                            .padding(.top, 4.0)
                            .padding(.bottom, 8.0)

                        Divider()
                            .background(Color.compound.bgSubtlePrimary)
                    }

                    if !actions.actions.isEmpty {
                        viewsForActions(actions.actions)

                        Divider()
                            .background(Color.compound.bgSubtlePrimary)
                    }
                    
                    viewsForActions(actions.debugActions)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.compound.bgCanvasDefault)
        .presentationDragIndicator(.visible)
    }
    
    private var header: some View {
        HStack(alignment: .top, spacing: 0.0) {
            LoadableAvatarImage(url: item.sender.avatarURL,
                                name: item.sender.displayName,
                                contentID: item.sender.id,
                                avatarSize: .user(on: .timeline),
                                imageProvider: context.imageProvider)
            
            Spacer(minLength: 8.0)
            
            VStack(alignment: .leading) {
                Text(item.sender.displayName ?? item.sender.id)
                    .font(.compound.bodySMSemibold)
                    .foregroundColor(.compound.textPrimary)
                
                Text(item.body.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 16.0)
            
            Text(item.timestamp)
                .font(.compound.bodyXS)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(.horizontal)
        .padding(.top, 32.0)
        .padding(.bottom, 4.0)
    }
    
    private var reactionsSection: some View {
        HStack(alignment: .center) {
            reactionButton(for: "👍️")
            reactionButton(for: "👎️")
            reactionButton(for: "🔥")
            reactionButton(for: "❤️")
            reactionButton(for: "👏")
            
            Button {
                dismiss()
                // Otherwise we get errors that a sheet is already presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    context.send(viewAction: .displayEmojiPicker(itemID: item.id))
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.compound.headingLG)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func reactionButton(for emoji: String) -> some View {
        Button {
            dismiss()
            context.send(viewAction: .toggleReaction(key: emoji, itemID: item.id))
        } label: {
            Text(emoji)
                .padding(8.0)
                .font(.compound.headingLG)
                .background(Circle()
                    .foregroundColor(reactionBackgroundColor(for: emoji)))
            
            Spacer()
        }
    }
    
    private func reactionBackgroundColor(for emoji: String) -> Color {
        if let reaction = item.properties.reactions.first(where: { $0.key == emoji }),
           reaction.isHighlighted {
            return .compound.bgActionPrimaryRest
        } else {
            return .clear
        }
    }
    
    private func viewsForActions(_ actions: [TimelineItemMenuAction]) -> some View {
        ForEach(actions, id: \.self) { action in
            Button { send(action) } label: {
                action.label
                    .labelStyle(FixedIconSizeLabelStyle())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
    
    private func send(_ action: TimelineItemMenuAction) {
        dismiss()
        // Otherwise we might get errors that a sheet is already presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.send(viewAction: .timelineItemMenuAction(itemID: item.id, action: action))
        }
    }
}

struct TimelineItemMenu_Previews: PreviewProvider {
    static let viewModel = RoomScreenViewModel.mock

    static var previews: some View {
        VStack {
            if let item = RoomTimelineItemFixtures.singleMessageChunk.first as? EventBasedTimelineItemProtocol,
               let actions = TimelineItemMenuActions(actions: [.copy, .edit, .reply, .redact], debugActions: [.viewSource]) {
                TimelineItemMenu(item: item, actions: actions)
            }
        }
        .environmentObject(viewModel.context)
    }
}
