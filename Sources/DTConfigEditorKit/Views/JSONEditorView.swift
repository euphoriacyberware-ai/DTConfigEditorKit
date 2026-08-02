import SwiftUI

/// A form-based editor for `DrawThingsConfiguration`, with fields grouped
/// by section according to `FieldRegistry`.
public struct JSONEditorView: View {
    @Binding public var config: DrawThingsConfiguration

    public init(config: Binding<DrawThingsConfiguration>) {
        self._config = config
    }

    public var body: some View {
        Form {
            ForEach(FieldRegistry.orderedSections, id: \.self) { section in
                Section(section.rawValue) {
                    ForEach(FieldRegistry.descriptors(for: section), id: \.key) { desc in
                        fieldRow(for: desc)
                    }
                }
            }

            lorasSection
            controlsSection
        }
    }

    // MARK: - Field row dispatch

    @ViewBuilder
    private func fieldRow(for desc: FieldDescriptor) -> some View {
        switch desc.controlType {
        case .toggle:
            if let kp = DrawThingsConfiguration.boolKeyPaths[desc.key] {
                Toggle(desc.label, isOn: $config[dynamicMember: kp])
            }

        case .integerField:
            if let kp = DrawThingsConfiguration.intKeyPaths[desc.key] {
                LabeledContent(desc.label) {
                    TextField("", value: $config[dynamicMember: kp], format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }

        case .decimalField:
            if let kp = DrawThingsConfiguration.doubleKeyPaths[desc.key] {
                LabeledContent(desc.label) {
                    TextField("", value: $config[dynamicMember: kp], format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }

        case .textField:
            if let kp = DrawThingsConfiguration.stringKeyPaths[desc.key] {
                LabeledContent(desc.label) {
                    TextField("", text: $config[dynamicMember: kp])
                        .multilineTextAlignment(.trailing)
                }
            }

        case .optionalText:
            if let kp = DrawThingsConfiguration.optionalStringKeyPaths[desc.key] {
                LabeledContent(desc.label) {
                    TextField("None", text: optionalStringBinding(kp))
                        .multilineTextAlignment(.trailing)
                }
            }

        case .readOnly:
            if let kp = DrawThingsConfiguration.intKeyPaths[desc.key] {
                LabeledContent(desc.label) {
                    Text("\(config[keyPath: kp])")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - LoRAs section

    @ViewBuilder
    private var lorasSection: some View {
        Section("LoRAs") {
            if config.loras.isEmpty {
                Text("None").foregroundStyle(.secondary)
            }
            ForEach(config.loras.indices, id: \.self) { i in
                loraRows(index: i)
            }
        }
    }

    @ViewBuilder
    private func loraRows(index i: Int) -> some View {
        if config.loras.count > 1 {
            Text("LoRA \(i + 1)")
                .font(.subheadline.weight(.medium))
        }
        LabeledContent("File") {
            TextField("", text: $config.loras[i].file)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Weight") {
            TextField("", value: $config.loras[i].weight, format: .number)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Mode") {
            TextField("", text: $config.loras[i].mode)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Controls section

    @ViewBuilder
    private var controlsSection: some View {
        Section("Controls") {
            if config.controls.isEmpty {
                Text("None").foregroundStyle(.secondary)
            }
            ForEach(config.controls.indices, id: \.self) { i in
                controlRows(index: i)
            }
        }
    }

    @ViewBuilder
    private func controlRows(index i: Int) -> some View {
        if config.controls.count > 1 {
            Text("Control \(i + 1)")
                .font(.subheadline.weight(.medium))
        }
        LabeledContent("File") {
            TextField("", text: $config.controls[i].file)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Weight") {
            TextField("", value: $config.controls[i].weight, format: .number)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Guidance Start") {
            TextField("", value: $config.controls[i].guidanceStart, format: .number)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Guidance End") {
            TextField("", value: $config.controls[i].guidanceEnd, format: .number)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Importance") {
            TextField("", text: $config.controls[i].controlImportance)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Binding helpers

    /// Bridge a `String?` property to a non-optional `String` binding
    /// for use with `TextField`. Empty string ↔ `nil`.
    private func optionalStringBinding(
        _ kp: WritableKeyPath<DrawThingsConfiguration, String?>
    ) -> Binding<String> {
        Binding<String>(
            get: { config[keyPath: kp] ?? "" },
            set: { config[keyPath: kp] = $0.isEmpty ? nil : $0 }
        )
    }
}
