import SwiftUI

private enum HabitEditorRoute: Hashable {
    case new
    case edit(EnergyHabit)

    var habit: EnergyHabit? {
        if case .edit(let habit) = self { return habit }
        return nil
    }

    var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}

struct HabitListView: View {
    @EnvironmentObject private var store: EnergyStore
    @State private var path: [HabitEditorRoute] = []
    @State private var searchText = ""
    @State private var pendingDeletion: EnergyHabit?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        overviewCard

                        if store.visibleHabits.isEmpty {
                            emptyCard
                        } else if filteredHabits.isEmpty {
                            searchEmptyCard
                        } else {
                            categorySections
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("我的元气小事")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索小事")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.new) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.rose)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.9), in: Circle())
                            .overlay { Circle().stroke(.white.opacity(0.96)) }
                            .shadow(color: AppTheme.rose.opacity(0.12), radius: 10, y: 4)
                    }
                    .accessibilityLabel("添加一件喜欢的小事")
                }
            }
            .navigationDestination(for: HabitEditorRoute.self) { route in
                HabitEditorView(
                    habit: route.habit,
                    onCancel: closeEditor,
                    onSave: { habit in save(habit, from: route) }
                )
            }
            .confirmationDialog(
                "删除“\(pendingDeletion?.localizedName ?? "")”？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除小事", role: .destructive) {
                    if let habit = pendingDeletion { store.delete(habit) }
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("删除后会从清单中移除，但过去的打卡和元气统计会保留。")
            }
        }
    }

    private var filteredHabits: [EnergyHabit] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.visibleHabits }
        return store.visibleHabits.filter {
            $0.localizedName.localizedCaseInsensitiveContains(query)
                || $0.category.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("把喜欢的小事放在手边")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cocoa)
                    Text("常用小事会优先出现在首页和小组件")
                        .font(.caption)
                        .foregroundStyle(AppTheme.cocoa.opacity(0.6))
                }
                Spacer()
                Text("\(store.favoriteHabits.count)/8")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.rose)
                    .contentTransition(.numericText())
            }

            if store.favoriteHabits.isEmpty {
                Label("点亮星星，收集你的常用小事", systemImage: "star")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.rose)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.blush.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 9)], spacing: 9) {
                    ForEach(Array(store.favoriteHabits.prefix(8))) { habit in
                        Button { path.append(.edit(habit)) } label: {
                            VStack(spacing: 7) {
                                Image(systemName: habit.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color(hex: habit.colorHex))
                                Text(habit.localizedName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.cocoa)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(Color(hex: habit.colorHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.95)) }
        .shadow(color: AppTheme.rose.opacity(0.08), radius: 14, y: 6)
    }

    private var emptyCard: some View {
        SoftCard {
            VStack(spacing: 14) {
                GentleEmptyState(
                    symbol: "sparkles",
                    title: "从一件喜欢的小事开始",
                    message: "不用列满清单，先留下此刻最想照顾自己的方式"
                )
                Button { path.append(.new) } label: {
                    Label("添加一件小事", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.rose)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    private var searchEmptyCard: some View {
        SoftCard {
            GentleEmptyState(
                symbol: "magnifyingglass",
                title: "没有找到这件小事",
                message: "换一个关键词试试看"
            )
            .padding(.vertical, 8)
        }
    }

    private var categorySections: some View {
        LazyVStack(spacing: 20) {
            ForEach(EnergyHabitCategory.allCases) { category in
                let habits = filteredHabits.filter { $0.category == category }
                if !habits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(category.title, systemImage: category.symbol)
                                .font(.headline)
                                .foregroundStyle(AppTheme.cocoa.opacity(0.78))
                            Spacer()
                            Text("\(habits.filter(\.isEnabled).count) 件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                                habitRow(habit)
                                if index < habits.count - 1 {
                                    Divider().padding(.leading, 66)
                                }
                            }
                        }
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.95)) }
                        .shadow(color: AppTheme.rose.opacity(0.055), radius: 10, y: 4)
                    }
                }
            }
        }
    }

    private func habitRow(_ habit: EnergyHabit) -> some View {
        HStack(spacing: 10) {
            Button { path.append(.edit(habit)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: habit.symbol)
                        .symbolRenderingMode(.monochrome)
                        .font(.title3)
                        .foregroundStyle(Color(hex: habit.colorHex))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: habit.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.localizedName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.cocoa)
                        if !habit.isEnabled {
                            Text("已从打卡页隐藏")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { store.toggleFavorite(habit) } label: {
                Image(systemName: habit.isFavorite ? "star.fill" : "star")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(habit.isFavorite ? AppTheme.gold : AppTheme.rose.opacity(0.38))
                    .frame(width: 38, height: 38)
                    .background(AppTheme.blush.opacity(habit.isFavorite ? 0.95 : 0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!habit.isEnabled || (!habit.isFavorite && store.favoriteHabits.count >= 8))
            .accessibilityLabel(habit.isFavorite ? "取消常用" : "设为常用")

            Menu {
                Button { path.append(.edit(habit)) } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button { store.toggleEnabled(habit) } label: {
                    Label(habit.isEnabled ? "暂时隐藏" : "重新显示", systemImage: habit.isEnabled ? "eye.slash" : "eye")
                }
                Divider()
                Button(role: .destructive) { pendingDeletion = habit } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.cocoa.opacity(0.5))
                    .frame(width: 34, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("更多操作")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(habit.isEnabled ? 1 : 0.55)
    }

    private func closeEditor() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private func save(_ habit: EnergyHabit, from route: HabitEditorRoute) {
        closeEditor()
        if route.isNew { store.add(habit) } else { store.update(habit) }
    }

}
