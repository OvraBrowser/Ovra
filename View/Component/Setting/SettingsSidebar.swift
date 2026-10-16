//
//  SettingsSidebar.swift
//  Ovra
//
//

import SwiftUI

struct SettingsSidebar: View {
  @Binding var selectedCategory: SettingsCategory
  @State private var searchText = ""

  @AppStorage(LocalProfile.nameKey) private var profileName: String = ""

  private var filteredCategories: [SettingsCategory] {
    let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
    guard !query.isEmpty else { return SettingsCategory.allCases }
    return SettingsCategory.allCases.filter { category in
      category.localizedTitle.lowercased().contains(query) || category.keywords.contains { $0.contains(query) }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Search
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(Color("UIText").opacity(0.5))
        TextField(NSLocalizedString("Search", comment: ""), text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .onSubmit {
            if let first = filteredCategories.first { selectedCategory = first }
          }
        if !searchText.isEmpty {
          Button { searchText = "" } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 11))
              .foregroundColor(Color("UIText").opacity(0.4))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(NSLocalizedString("Clear search", comment: ""))
        }
      }
      .padding(.horizontal, 8)
      .frame(height: 28)
      .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color("UIText").opacity(0.06)))

      // Profile
      HStack(spacing: 10) {
        Text(LocalProfile.initial(profileName))
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 32, height: 32)
          .background(Circle().fill(LinearGradient(colors: [Color(hex: "#8E8E93"), Color(hex: "#5C5C61")], startPoint: .topLeading, endPoint: .bottomTrailing)))
        VStack(alignment: .leading, spacing: 1) {
          Text(LocalProfile.displayName(profileName))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color("UIText"))
            .lineLimit(1)
          Text(NSLocalizedString("Local profile", comment: ""))
            .font(.system(size: 11))
            .foregroundColor(Color("UIText").opacity(0.55))
        }
      }
      .padding(8)
      .padding(.top, 6)

      // Sections
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 2) {
          ForEach(filteredCategories, id: \.self) { category in
            SettingsSidebarItem(category: category, isSelected: selectedCategory == category) {
              selectedCategory = category
            }
          }
          if filteredCategories.isEmpty {
            Text(NSLocalizedString("No results", comment: ""))
              .font(.system(size: 12))
              .foregroundColor(Color("UIText").opacity(0.5))
              .padding(.top, 12)
          }
        }
        .padding(.top, 6)
      }

      Spacer(minLength: 0)

      if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        Text("Ovra \(version)")
          .font(.system(size: 10))
          .foregroundColor(Color("UIText").opacity(0.4))
          .padding(.leading, 8)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 12)
    .frame(width: 230)
    .frame(maxHeight: .infinity)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.settingsSidebar))
  }
}

struct SettingsSidebarItem: View {
  let category: SettingsCategory
  let isSelected: Bool
  let action: () -> Void

  @State private var isHover = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        if isSelected {
          SettingsIconBadge(symbol: category.icon, colors: [.white.opacity(0.28), .white.opacity(0.22)])
        } else {
          SettingsIconBadge(symbol: category.icon, colors: category.iconColors)
        }
        Text(category.localizedTitle)
          .font(.system(size: 13))
          .foregroundColor(isSelected ? .white : Color("UIText"))
        Spacer()
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? Color.settingsAccent : Color("UIText").opacity(isHover ? 0.05 : 0))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .onHover { isHover = $0 }
  }
}
