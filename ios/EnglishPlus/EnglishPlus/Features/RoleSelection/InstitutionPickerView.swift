import SwiftUI

struct InstitutionPickerView: View {
    @Binding var selection: EducationInstitution?

    @State private var query = ""
    @State private var showsDirectory = false

    private let directory = EducationInstitutionDirectory(
        institutions: SeedData.educationInstitutions
    )

    private var results: [EducationInstitution] {
        directory.search(.init(text: query), limit: 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任職學校或教育機構")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)

            if let selection {
                selectedInstitution(selection)
            } else {
                Button {
                    showsDirectory = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.title3)
                            .foregroundStyle(EPTheme.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("從教育機構名錄選擇")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EPTheme.ink)
                            Text("搜尋校名、縣市或學校代碼")
                                .font(.caption)
                                .foregroundStyle(EPTheme.secondaryInk)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(EPTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(EPTheme.secondarySurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                            .stroke(EPTheme.hairline, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }
                .buttonStyle(.plain)
            }

            Label(
                "內含教育部公開名錄共 \(directory.institutions.count.formatted()) 筆；這裡記錄任職資訊，不代表 English+ 已驗證教師資格。",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(EPTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $showsDirectory) {
            directorySheet
        }
    }

    private var directorySheet: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("選擇教育機構")
                                .font(.title2.bold())
                                .foregroundStyle(EPTheme.ink)
                            Text("輸入至少 2 個字，然後點選搜尋結果。輸入內容不會直接當作學校名稱保存。")
                                .font(.subheadline)
                                .foregroundStyle(EPTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        searchField
                        searchResults

                        NavigationLink {
                            ManualInstitutionEntryView(selection: $selection)
                        } label: {
                            Label("名錄找不到？新增實驗教育機構或自學團體", systemImage: "plus.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EPTheme.primary)
                    }
                    .padding(EPTheme.pagePadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { showsDirectory = false }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: selection) { _, newSelection in
            if newSelection != nil {
                showsDirectory = false
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(EPTheme.secondaryInk)
            TextField("例如：宜蘭、復興國中或學校代碼", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(EPTheme.secondaryInk)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private var searchResults: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Label("搜尋後會在這裡顯示可選擇的學校。", systemImage: "text.magnifyingglass")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        } else if trimmed.count == 1 {
            Text("再輸入 1 個字，就會開始搜尋名錄。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
        } else if results.isEmpty {
            Label("名錄中找不到相符機構，請換校名或縣市搜尋。", systemImage: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
        } else {
            VStack(spacing: 0) {
                ForEach(results) { institution in
                    Button {
                        selection = institution
                        query = ""
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .foregroundStyle(EPTheme.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(institution.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(EPTheme.ink)
                                    .multilineTextAlignment(.leading)
                                Text(institutionSubtitle(institution))
                                    .font(.caption)
                                    .foregroundStyle(EPTheme.secondaryInk)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(EPTheme.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    if institution.id != results.last?.id {
                        Divider().overlay(EPTheme.hairline)
                    }
                }
            }
            .background(EPTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                    .stroke(EPTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
    }

    private func selectedInstitution(_ institution: EducationInstitution) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EPTheme.support)
            VStack(alignment: .leading, spacing: 3) {
                Text(institution.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EPTheme.ink)
                Text(
                    institution.source == .ministryOfEducation
                        ? "教育部名錄 · 任職資訊由本人聲明"
                        : "自行新增 · 任職資訊尚未驗證"
                )
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            }
            Spacer()
            Button("更換") {
                selection = nil
                showsDirectory = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(EPTheme.primary)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func institutionSubtitle(_ institution: EducationInstitution) -> String {
        [institution.city, institution.district, institution.officialCode]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private struct ManualInstitutionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: EducationInstitution?

    @State private var name = ""
    @State private var kind: EducationInstitutionKind = .otherEducationOrganization

    var body: some View {
        Form {
            Section("教育機構資料") {
                TextField("機構或團體名稱", text: $name)
                Picker("類型", selection: $kind) {
                    Text("實驗教育機構").tag(EducationInstitutionKind.experimentalEducationInstitution)
                    Text("自學團體").tag(EducationInstitutionKind.homeschoolGroup)
                    Text("其他教育組織").tag(EducationInstitutionKind.otherEducationOrganization)
                }
            }
            Section {
                Text("只在教育部名錄找不到時使用。自行新增的機構會標示為未驗證，不等同教師資格審核。")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .navigationTitle("新增教育機構")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("使用") {
                    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    selection = EducationInstitution(
                        id: "user-\(UUID().uuidString.lowercased())",
                        officialCode: nil,
                        name: cleaned,
                        city: nil,
                        district: nil,
                        kind: kind,
                        source: .userSubmitted,
                        sourceDatasetId: nil,
                        sourceAcademicYear: nil,
                        isActive: true
                    )
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }
        }
    }
}
