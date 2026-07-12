import SwiftUI

struct InstitutionPickerView: View {
    @Binding var selection: EducationInstitution?

    @State private var query = ""
    @State private var showsManualEntry = false
    @State private var manualName = ""
    @State private var manualKind: EducationInstitutionKind = .otherEducationOrganization

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
                searchField
                searchResults
                Button("找不到機構？自行填寫") {
                    showsManualEntry = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EPTheme.primary)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showsManualEntry) {
            manualEntrySheet
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(EPTheme.secondaryInk)
            TextField("輸入校名、縣市或學校代碼", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private var searchResults: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 1 {
            Text("再輸入一個字就能開始搜尋")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
        } else if trimmed.count >= 2 && results.isEmpty {
            Text("沒有找到相符機構，可以換個關鍵字或自行填寫。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
        } else if !results.isEmpty {
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
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(EPTheme.secondaryInk)
                        }
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    if institution.id != results.last?.id {
                        Divider().overlay(EPTheme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
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
                Text(institution.source == .ministryOfEducation ? "教育部名錄" : "自行填寫，尚未驗證")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
            Spacer()
            Button("更改") {
                selection = nil
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(EPTheme.primary)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section("機構資料") {
                    TextField("機構或團體名稱", text: $manualName)
                    Picker("類型", selection: $manualKind) {
                        Text("實驗教育機構").tag(EducationInstitutionKind.experimentalEducationInstitution)
                        Text("自學團體").tag(EducationInstitutionKind.homeschoolGroup)
                        Text("其他教育組織").tag(EducationInstitutionKind.otherEducationOrganization)
                    }
                }
                Section {
                    Text("自行填寫的機構會標示為尚未驗證，不會被當成教育部正式名錄。")
                        .font(.footnote)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
            }
            .navigationTitle("新增教育機構")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showsManualEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用") {
                        let cleaned = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
                        selection = EducationInstitution(
                            id: "user-\(UUID().uuidString.lowercased())",
                            officialCode: nil,
                            name: cleaned,
                            city: nil,
                            district: nil,
                            kind: manualKind,
                            source: .userSubmitted,
                            sourceDatasetId: nil,
                            sourceAcademicYear: nil,
                            isActive: true
                        )
                        manualName = ""
                        showsManualEntry = false
                    }
                    .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
    }

    private func institutionSubtitle(_ institution: EducationInstitution) -> String {
        [institution.city, institution.officialCode]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
