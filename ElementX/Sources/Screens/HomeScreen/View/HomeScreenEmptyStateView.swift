//
// Copyright 2023 New Vector Ltd
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

import Combine
import Compound
import SwiftUI

/// The view shown when the user isn't part of any rooms.
struct HomeScreenEmptyStateView: View {
    let context: HomeScreenViewModel.Context
    
    var body: some View {
        VStack(spacing: 6) {
            Text(L10n.screenRoomlistEmptyTitle)
                .font(.compound.bodyLG)
                .foregroundColor(.compound.textSecondary)
                .multilineTextAlignment(.center)
            
            Text(L10n.screenRoomlistEmptyMessage)
                .font(.compound.bodyLG)
                .foregroundColor(.compound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            
            Button { context.send(viewAction: .startChat) } label: {
                Label(L10n.actionStartChat, icon: \.compose)
                    .font(.compound.bodyLGSemibold)
                    .foregroundColor(.compound.textOnSolidPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 22)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(16)
    }
}

/// A custom layout for the empty state which will show it centrally with the
/// session verification banner and invites button stacked at the top.
struct HomeScreenEmptyStateLayout: Layout {
    /// The vertical spacing between views in the layout.
    var spacing: CGFloat = 8
    /// The minimum height of the layout. This should be the height of the scroll view.
    var minHeight: CGFloat = 0
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // We keep the proposed width and replace the height with the minimum specified,
        // or the total height of the subviews if it exceeds the minimum height.
        let width = proposal.width ?? .greatestFiniteMagnitude
        var height: CGFloat = spacing * CGFloat(max(0, subviews.count - 1))
        
        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            height += size.height
        }
        
        return CGSize(width: width, height: max(minHeight, height))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let mainView = subviews.first(where: { $0.priority > 0 })
        let topViews = subviews.filter { $0 != mainView }
        
        var y: CGFloat = bounds.minY
        
        // Place all the top views in a vertical stack, centering horizontally.
        for view in topViews {
            let size = view.sizeThatFits(proposal)
            let x = (bounds.width - size.width) / 2
            view.place(at: CGPoint(x: x, y: y), proposal: proposal)
            y += size.height + spacing
        }
        
        // Place the main view in the center if there is space, otherwise add it to the stack.
        guard let mainView else { return }

        let mainViewSize = mainView.sizeThatFits(proposal)
        if (y + mainViewSize.height / 2) < bounds.height / 2 {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            mainView.place(at: center, anchor: .center, proposal: proposal)
        } else {
            let x = (bounds.width - mainViewSize.width) / 2
            mainView.place(at: CGPoint(x: x, y: y), proposal: proposal)
        }
    }
}

// MARK: - Previews

struct HomeScreenEmptyStateView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        HomeScreenEmptyStateView(context: viewModel.context)
            .previewDisplayName("View")
        
        GeometryReader { geometry in
            ScrollView {
                HomeScreenEmptyStateLayout(minHeight: geometry.size.height) {
                    banner
                    
                    HomeScreenEmptyStateView(context: viewModel.context)
                        .layoutPriority(1)
                }
            }
        }
        .previewDisplayName("Normal Layout")
        
        GeometryReader { geometry in
            ScrollView {
                HomeScreenEmptyStateLayout(minHeight: geometry.size.height) {
                    banner
                    banner
                    banner
                    
                    HomeScreenEmptyStateView(context: viewModel.context)
                        .layoutPriority(1)
                }
            }
        }
        .previewDisplayName("Constrained layout")
    }
    
    // MARK: -
    
    static var banner: some View {
        Text("This is a title that is very long")
            .font(.compound.headingXLBold)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.compound.bgSubtleSecondary)
            }
            .padding()
    }
    
    static let viewModel = {
        let userSession = MockUserSession(clientProxy: ClientProxyMock(.init(userID: "@user:example.com",
                                                                             roomSummaryProvider: MockRoomSummaryProvider(state: .loaded([])))),
                                          mediaProvider: MockMediaProvider(),
                                          voiceMessageMediaManager: VoiceMessageMediaManagerMock())
        
        return HomeScreenViewModel(userSession: userSession,
                                   analyticsService: ServiceLocator.shared.analytics,
                                   appSettings: ServiceLocator.shared.settings,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   userIndicatorController: ServiceLocator.shared.userIndicatorController)
    }()
}
