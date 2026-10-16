import SwiftUI
import SwiftData

struct NewTabView: View {
  @Query(sort: \Favorite.createDate, order: .forward) var favorites: [Favorite]
  @Query(sort: \VisitHistoryGroup.updateDate, order: .reverse) var recentVisits: [VisitHistoryGroup]
  @Query var generalSettings: [GeneralSetting]
  @Environment(\.modelContext) var modelContext
  @EnvironmentObject var service: Service

  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab

  @State private var showEditDialog = false
  @State private var editingFavorite: Favorite?
  @State private var showContextMenu: Favorite?

  @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
  // Observed so text colour updates when a custom theme is edited.
  @AppStorage("customThemes") private var customThemesData: Data = Data()

  @AppStorage(LocalProfile.nameKey) private var profileName: String = ""

  private let maxFavorites = 6

  private var foreground: Color { ThemeForeground.color(for: selectedTheme) }

  private var greeting: String {
    let firstName = LocalProfile.firstName(profileName)
    let hour = Calendar.current.component(.hour, from: Date())
    let format: String
    switch hour {
    case 5..<12: format = NSLocalizedString("Good morning, %@", comment: "")
    case 12..<18: format = NSLocalizedString("Good afternoon, %@", comment: "")
    default: format = NSLocalizedString("Good evening, %@", comment: "")
    }
    return String(format: format, firstName)
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 0) {
        Image("MainLogo")
          .resizable()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
          .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
          .accessibilityHidden(true)

        Text(greeting)
          .font(.system(size: 30, weight: .semibold))
          .tracking(-0.4)
          .foregroundColor(foreground)
          .padding(.top, 22)

        VStack(alignment: .leading, spacing: 14) {
          Text(NSLocalizedString("Favorites", comment: ""))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(foreground)

          FavoriteGrid(
            favorites: favorites,
            browser: browser,
            tab: tab,
            editingFavorite: $editingFavorite,
            showEditDialog: $showEditDialog,
            showContextMenu: $showContextMenu,
            maxFavorites: maxFavorites,
            containerWidth: 760
          )
        }
        .frame(maxWidth: 760, alignment: .leading)
        .padding(.top, 44)

        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 16) { protectionCard; recentCard }
          VStack(spacing: 16) { protectionCard; recentCard }
        }
        .frame(maxWidth: 760)
        .padding(.top, 40)

        Button {
          browser.showSettings(category: .Theme)
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
              .font(.system(size: 11, weight: .medium))
            Text(NSLocalizedString("Customize Start Page", comment: ""))
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundColor(foreground)
          .padding(.horizontal, 14)
          .frame(height: 30)
          .background(Capsule().fill(foreground.opacity(0.16)))
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 28)
      }
      .padding(.horizontal, 32)
      .padding(.top, 72)
      .padding(.bottom, 40)
      .frame(maxWidth: .infinity)
    }
    .overlay(
      Group {
        if showEditDialog {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
              showEditDialog = false
              editingFavorite = nil
            }

          FavoriteEditDialog(
            isPresented: $showEditDialog,
            editingFavorite: $editingFavorite
          )
        }
      }
    )
  }

  // MARK: - Cards

  private var protectionCard: some View {
    StartPageCard(foreground: foreground) {
      HStack(spacing: 8) {
        Image(systemName: service.isTrackerBlocking ? "shield.lefthalf.filled" : "shield.slash")
          .font(.system(size: 14, weight: .semibold))
        Text(NSLocalizedString("Privacy Protection", comment: ""))
          .font(.system(size: 15, weight: .semibold))
        Spacer()
        Toggle("", isOn: Binding(
          get: { service.isTrackerBlocking },
          set: { newValue in
            service.isTrackerBlocking = newValue
            generalSettings.first?.isTrackerBlocking = newValue
          }
        ))
        .toggleStyle(.switch)
        .labelsHidden()
        .controlSize(.small)
        .accessibilityLabel(NSLocalizedString("Block trackers", comment: ""))
      }
      Text(service.isTrackerBlocking
           ? NSLocalizedString("Trackers are blocked on every site you visit.", comment: "")
           : NSLocalizedString("Tracker blocking is off.", comment: ""))
        .font(.system(size: 13))
        .foregroundColor(foreground.opacity(0.85))
        .padding(.top, 12)
      Button {
        browser.showSettings(category: .permissions)
      } label: {
        HStack(spacing: 4) {
          Text(NSLocalizedString("Site permissions", comment: ""))
          Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(foreground)
      }
      .buttonStyle(.plain)
      .padding(.top, 14)
    }
  }

  private var recentCard: some View {
    StartPageCard(foreground: foreground) {
      HStack(spacing: 8) {
        Image(systemName: "clock")
          .font(.system(size: 14, weight: .semibold))
        Text(NSLocalizedString("Recently Visited", comment: ""))
          .font(.system(size: 15, weight: .semibold))
      }
      VStack(spacing: 2) {
        if recentVisits.isEmpty {
          Text(NSLocalizedString("Pages you visit will show up here.", comment: ""))
            .font(.system(size: 13))
            .foregroundColor(foreground.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
          ForEach(recentVisits.prefix(3)) { visit in
            RecentVisitRow(visit: visit, foreground: foreground) {
              if let url = URL(string: visit.url) {
                tab.updateURLBySearch(url: url)
              }
            }
          }
        }
      }
      .padding(.top, 8)
    }
  }
}

// MARK: - Pieces

private struct StartPageCard<Content: View>: View {
  let foreground: Color
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .foregroundColor(foreground)
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(foreground.opacity(0.14))
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(foreground.opacity(0.2), lineWidth: 0.5)
        )
    )
  }
}

private struct RecentVisitRow: View {
  let visit: VisitHistoryGroup
  let foreground: Color
  let action: () -> Void

  @State private var isHovered = false

  private var title: String {
    if let title = visit.title, !title.isEmpty { return title }
    return URL(string: visit.url)?.host() ?? visit.url
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Group {
          if let data = visit.faviconData, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(3)
          } else {
            Text(String(title.prefix(1)).uppercased())
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(Color(red: 0.14, green: 0.16, blue: 0.18))
          }
        }
        .frame(width: 22, height: 22)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.9)))

        Text(title)
          .font(.system(size: 13))
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 8)
        Text(visit.updateDate, format: .relative(presentation: .named))
          .font(.system(size: 12))
          .foregroundColor(foreground.opacity(0.75))
      }
      .padding(8)
      .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(foreground.opacity(isHovered ? 0.1 : 0)))
      .padding(.horizontal, -8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
