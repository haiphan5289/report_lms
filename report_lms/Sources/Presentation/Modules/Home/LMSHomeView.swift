//
//  LMSHome.swift
//  report_lms
//
//  Created by AI on January 21, 2026.
//

import SwiftUI

struct LMSHome: View {
    // MARK: - Properties
    @State private var showMenu = false
    @State private var showCloudAction = false
    @State private var selectedTab: Tab = .plan

    enum Tab: Int, CaseIterable {
        case plan, inProgress, report
        var title: String {
            switch self {
            case .plan: return "Kế hoạch"
            case .inProgress: return "Trong tiến trình"
            case .report: return "Báo cáo"
            }
        }
        var icon: String {
            switch self {
            case .plan: return "calendar"
            case .inProgress: return "clock.arrow.circlepath"
            case .report: return "doc.text.magnifyingglass"
            }
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showMenu) {
            // Placeholder for menu action
            VStack {
                LMSLabel("Menu action triggered!", style: .title, alignment: .center)
                Spacer()
            }
            .padding()
        }
        .alert("Cloud action triggered!", isPresented: $showCloudAction) {
            Button("OK", role: .cancel) {}
        }
    }
    
    // MARK: - Private Views
    private var header: some View {
        HStack {
            LMSButton("", icon: "line.3.horizontal", variant: .iconOnly, action: { showMenu = true })
                .frame(width: 44, height: 44)
            Spacer()
            LMSLabel("Kiểm tra", style: .title, alignment: .center)
            Spacer()
            LMSButton("", icon: "cloud", variant: .iconOnly, action: { showCloudAction = true })
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .shadow(color: Color(.black).opacity(0.04), radius: 2, y: 1)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \ .self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            LMSLabel(tab.title,
                                     style: .body,
                                     color: selectedTab == tab ? .custom(Color.accentColor) : .secondary,
                                     alignment: .center)
                               .fontWeight(selectedTab == tab ? .semibold : .regular)
                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tabUnderline", in: tabBarNamespace)
                            } else {
                                Color.clear.frame(height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 0)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .padding(.bottom, 2)
    }

    @Namespace private var tabBarNamespace

    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .plan:
                PlanLMSHomeView()
            case .inProgress:
                VStack { LMSLabel("Nội dung Trong tiến trình", style: .body, alignment: .center) }
            case .report:
                VStack { LMSLabel("Nội dung Báo cáo", style: .body, alignment: .center) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut, value: selectedTab)
    }
}

// MARK: - Preview

#Preview {
    LMSHome()
}

