//
//  OvraSidebar.swift
//  Ovra
//
//  Floating glass sidebar: vertical tabs, library shortcuts and the profile card.
//

import SwiftUI

struct OvraSidebar: View {
  @ObservedObject var service: Service
  @ObservedObject var browser: Browser

  @ObservedObject private var downloadManager = DownloadManager.shared
  @State private var isDownloadsPopover = false

  @AppStorage(LocalProfile.nameKey) private var profileName: String = ""

  private var firstName: String { LocalProfile.firstName(profileName) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header: room for the traffic lights + hide button
      HStack(spacing: 0) {
        Spacer()
        SidebarIconButton(icon: "sidebar.left", label: NSLocalizedString("Hide Sidebar", comment: "")) {
          withAnimation(.easeInOut(duration: 0.2)) { browser.isTabSidebar = false }
        }
      }
      .frame(height: 32)
      .padding(.horizontal, 4)

      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            SidebarSectionTitle(NSLocalizedString("Tabs", comment: ""))
            Spacer()
            SidebarIconButton(icon: "plus", label: NSLocalizedString("New Tab", comment: ""), size: 22) {
              browser.initTab()
            }
          }
          .padding(.trailing, 4)

          VStack(spacing: 1) {
            ForEach(browser.tabs, id: \.id) { tab in
              SidebarTabRow(browser: browser, tab: tab)
            }
          }
          .padding(.top, 6)

          SidebarSectionTitle(NSLocalizedString("Library", comment: ""))
            .padding(.top, 18)

          VStack(spacing: 1) {
            SidebarLinkRow(icon: "book", title: NSLocalizedString("Bookmarks", comment: ""), isActive: browser.isSideBar) {
              withAnimation(.easeInOut(duration: 0.2)) { browser.isSideBar.toggle() }
            }
            SidebarLinkRow(icon: "clock", title: NSLocalizedString("History", comment: ""), isActive: false) {
              browser.showSettings(category: .visitHistory)
            }
            SidebarLinkRow(icon: "arrow.down.circle", title: NSLocalizedString("Downloads", comment: ""), isActive: isDownloadsPopover, badge: downloadManager.hasActiveDownloads) {
              isDownloadsPopover.toggle()
            }
            .popover(isPresented: $isDownloadsPopover, arrowEdge: .trailing) {
              DownloadsPopover()
            }
          }
          .padding(.top, 6)
        }
        .padding(.top, 14)
      }

      Spacer(minLength: 8)

      // Profile card
      Button {
        browser.showSettings(category: .general)
      } label: {
        HStack(spacing: 10) {
          Text(LocalProfile.initial(profileName))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(
              Circle().fill(LinearGradient(colors: [Color(hex: "#8E8E93"), Color(hex: "#5C5C61")], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
          VStack(alignment: .leading, spacing: 1) {
            Text(firstName)
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(Color("UIText"))
            Text(NSLocalizedString("Settings", comment: ""))
              .font(.system(size: 11))
              .foregroundColor(Color("UIText").opacity(0.6))
          }
          Spacer(minLength: 0)
          Image(systemName: "gearshape")
            .font(.system(size: 13))
            .foregroundColor(Color("UIText").opacity(0.6))
        }
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.glassSelection.opacity(0.6))
        )
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
    .frame(width: 252)
    .frame(maxHeight: .infinity)
    .background(GlassPanelBackground(cornerRadius: 20))
  }
}

// MARK: - Rows

private struct SidebarSectionTitle: View {
  let title: String
  init(_ title: String) { self.title = title }

  var body: some View {
    Text(title)
      .font(.system(size: 11, weight: .semibold))
      .foregroundColor(Color("UIText").opacity(0.5))
      .padding(.horizontal, 8)
  }
}

private struct SidebarIconButton: View {
  let icon: String
  let label: String
  var size: CGFloat = 28
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: size > 24 ? 14 : 12, weight: .medium))
        .foregroundColor(Color("UIText").opacity(0.75))
        .frame(width: size + 2, height: size)
        .background(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color("UIText").opacity(isHovered ? 0.08 : 0))
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
    .onHover { isHovered = $0 }
  }
}

private struct SidebarLinkRow: View {
  let icon: String
  let title: String
  let isActive: Bool
  var badge: Bool = false
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13))
          .foregroundColor(Color("UIText").opacity(0.75))
          .frame(width: 16)
        Text(title)
          .font(.system(size: 13))
          .foregroundColor(Color("UIText"))
        Spacer()
        if badge {
          Circle().fill(Color.accentColor).frame(width: 6, height: 6)
        }
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color("UIText").opacity(isActive ? 0.08 : (isHovered ? 0.05 : 0)))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

private struct SidebarTabRow: View {
  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab

  @State private var isHovered = false
  @State private var isCloseHovered = false
  @State private var spin = false

  private var isActive: Bool { tab.id == browser.activeTabId }

  private var title: String {
    if tab.isInit { return NSLocalizedString("New Tab", comment: "") }
    if tab.isSetting { return NSLocalizedString("Settings", comment: "") }
    return tab.title.isEmpty ? tab.printURL : tab.title
  }

  var body: some View {
    HStack(spacing: 10) {
      favicon
        .frame(width: 16, height: 16)

      Text(title)
        .font(.system(size: 13, weight: isActive ? .medium : .regular))
        .foregroundColor(Color("UIText"))
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer(minLength: 0)

      if isHovered || isActive {
        Button {
          browser.closeTab(tab)
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Color("UIText").opacity(isCloseHovered ? 0.9 : 0.5))
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color("UIText").opacity(isCloseHovered ? 0.1 : 0)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("Close Tab", comment: ""))
        .onHover { isCloseHovered = $0 }
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 6)
    .frame(height: 32)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(isActive ? Color.glassSelection : Color("UIText").opacity(isHovered ? 0.05 : 0))
        .shadow(color: .black.opacity(isActive ? 0.1 : 0), radius: 1.5, y: 1)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      browser.clearSearchEditMode()
      browser.activeTabId = tab.id
    }
    .onHover { isHovered = $0 }
    .contextMenu {
      Button(NSLocalizedString("Close Tab", comment: "")) { browser.closeTab(tab) }
      Button(NSLocalizedString("Close Other Tabs", comment: "")) {
        for other in browser.tabs where other.id != tab.id {
          browser.closeTab(other)
        }
      }
    }
    .onAppear { spin = tab.pageProgress > 0 }
    .onChange(of: tab.pageProgress) { _, nV in spin = nV > 0 && nV < 1 }
  }

  @ViewBuilder
  private var favicon: some View {
    if tab.isInit || tab.isSetting {
      Image("MainLogo")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 15, height: 15)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    } else if tab.pageProgress > 0 && tab.pageProgress < 1 && tab.favicon == nil {
      Circle()
        .trim(from: 0, to: 0.7)
        .stroke(Color("Icon").opacity(0.6), lineWidth: 1.5)
        .frame(width: 12, height: 12)
        .rotationEffect(.degrees(spin ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
    } else if let favicon = tab.favicon {
      favicon
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 16, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    } else {
      Image(systemName: "globe")
        .font(.system(size: 12))
        .foregroundColor(Color("Icon").opacity(0.6))
    }
  }
}
