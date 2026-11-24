import SwiftUI

struct HabitEditorView: View {
    @EnvironmentObject private var store: EnergyStore
    private let original: EnergyHabit?
    private let onCancel: () -> Void
    private let onSave: (EnergyHabit) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var category: EnergyHabitCategory
    @State private var isFavorite: Bool
    @State private var celebrate = true
    @State private var isSubmitting = false
    @FocusState private var isNameFocused: Bool

    private let symbols = [
        "sun.max.fill", "book.closed.fill", "figure.mind.and.body", "tree.fill", "drop.fill", "pencil.and.scribble",
        "house.fill", "heart.fill", "headphones", "moon.stars.fill", "leaf.fill", "bed.double.fill",
        "figure.flexibility", "cloud.rain.fill", "cat.fill", "shower.fill", "paintpalette.fill", "drop.fill",
        "tshirt.fill", "cup.and.saucer.fill", "wind", "fork.knife", "mountain.2.fill", "face.smiling.fill",
        "basket.fill", "building.columns.fill", "book.pages.fill", "bird.fill", "bathtub.fill"
    ]
    private let colors = ["F45F7A", "FF8D9C", "FF9D69", "FFC857", "8FBB75", "67B8C4", "9A82DE", "E88BB7"]

    init(
        habit: EnergyHabit? = nil,
        onCancel: @escaping () -> Void = {},
        onSave: @escaping (EnergyHabit) -> Void = { _ in }
    ) {
        original = habit
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: habit?.localizedName ?? "")
        _symbol = State(initialValue: habit?.symbol ?? "sun.max.fill")
        _colorHex = State(initialValue: habit?.colorHex ?? "F45F7A")
        _category = State(initialValue: habit?.category ?? .personal)
        _isFavorite = State(initialValue: habit?.isFavorite ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                editorSection("名称") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("输入小事名称", text: $name)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit { isNameFocused = false }
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                        Label("记录一次，就收获 +1 元气", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(AppTheme.rose)
                    }
                }

                editorSection("分类") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(EnergyHabitCategory.allCases) { item in
                            Button {
                                category = item
                            } label: {
                                VStack(spacing: 7) {
                                    Image(systemName: item.symbol)
                                        .font(.title3)
                                    Text(item.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .foregroundStyle(category == item ? .white : AppTheme.cocoa)
                                .frame(maxWidth: .infinity)
                                .frame(height: 68)
                                .background(
                                    category == item ? AppTheme.rose : AppTheme.blush,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.rose.opacity(category == item ? 0 : 0.14))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(category == item ? .isSelected : [])
                        }
                    }
                    Text("保存后会出现在所选分类中，也可以随时重新调整")
                        .font(.caption)
                        .foregroundStyle(AppTheme.cocoa.opacity(0.58))
                }

                editorSection("图标") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 12)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(symbols, id: \.self) { item in
                        Button { symbol = item } label: {
                            Image(systemName: item)
                                .symbolRenderingMode(.monochrome)
                                .font(.title3)
                                .foregroundColor(Color(hex: colorHex))
                                .frame(width: 44, height: 44)
                                .background(AppTheme.blush, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(symbol == item ? AppTheme.rose : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 5)
                }

                editorSection("颜色") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 12)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(colors, id: \.self) { item in
                        Button { colorHex = item } label: {
                            ZStack {
                                Color.clear
                                Circle()
                                    .fill(Color(hex: item))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(.white, lineWidth: 3).padding(3))
                                    .overlay(Circle().stroke(colorHex == item ? AppTheme.rose : .clear, lineWidth: 2))
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                }

                editorSection("首页常用") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("在首页常用中显示", isOn: $isFavorite)
                            .tint(AppTheme.rose)
                            .disabled(!canBecomeFavorite)
                        Text(favoriteHint)
                            .font(.caption)
                            .foregroundStyle(canBecomeFavorite ? AppTheme.cocoa.opacity(0.58) : AppTheme.rose)
                    }
                }

                editorSection("小小庆祝") {
                    VStack(spacing: 14) {
                        Toggle("为我庆祝一下 ✦", isOn: $celebrate)
                        Divider()
                        Label("每天", systemImage: "calendar")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(original == nil ? String(localized: "添加一件喜欢的小事") : String(localized: "编辑元气小事"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    isNameFocused = false
                    onCancel()
                }
                .disabled(isSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isNameFocused = false }
                    .fontWeight(.semibold)
            }
        }
    }

    private func editorSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.9))
                .allowsHitTesting(false)
        }
    }

    private func save() {
        guard !isSubmitting else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        isSubmitting = true
        isNameFocused = false

        var result: EnergyHabit
        if var original {
            original.name = cleanName == original.localizedName ? original.name : cleanName
            original.symbol = symbol
            original.colorHex = colorHex
            original.category = category
            original.isFavorite = isFavorite && canBecomeFavorite
            result = original
        } else {
            result = EnergyHabit(name: cleanName, symbol: symbol, colorHex: colorHex, category: category)
            result.isFavorite = isFavorite && canBecomeFavorite
        }
        onSave(result)
    }

    private var canBecomeFavorite: Bool {
        original?.isFavorite == true || store.favoriteHabits.count < 8
    }

    private var favoriteHint: String {
        if canBecomeFavorite {
            return String(localized: "常用小事会出现在首页，随时可以回来调整")
        }
        return String(localized: "首页已有 8 个常用小事，取消一个后就能选择")
    }
}
