import MouseScrollFixCore
import SwiftUI

struct DevicesView: View {
    @ObservedObject var model: AppStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.text(.devicesTitle)).font(.headline)
                Spacer()
                Button(model.text(.devicesRefresh)) { model.inventoryService.refresh() }
            }

            let pointers = model.inventory.devices.filter { !$0.isVirtual }
            if pointers.isEmpty {
                Text(model.text(.devicesEmpty)).foregroundStyle(.secondary)
            } else {
                List(pointers) { device in
                    DeviceRow(model: model, device: device)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            Divider()

            Text(model.text(.devicesFooter))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !model.isAccessibilityTrusted {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(model.text(.devicesPermissionWarning)).font(.callout)
                    Spacer()
                    Button(model.text(.buttonOpenSettings)) { model.openAccessibilitySettings() }
                }
            }
        }
        .padding()
    }
}

private struct DeviceRow: View {
    @ObservedObject var model: AppStatusModel
    let device: PointerDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.body)
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.describe(device).kind)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(kindColor.opacity(0.15))
                .foregroundStyle(kindColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        var parts: [String] = []
        parts.append(String(format: "VID 0x%04X · PID 0x%04X", device.vendorID, device.productID))
        if !device.transport.isEmpty { parts.append(device.transport) }
        if device.isBuiltIn == true { parts.append(model.text(.labelBuiltIn)) }
        return parts.joined(separator: " · ")
    }

    private var iconName: String {
        switch device.kind {
        case .mouse: return "computermouse"
        case .builtInTrackpad, .externalTrackpad: return "rectangle.and.hand.point.up.left"
        case .touchSurface: return "magicmouse"
        case .unknown: return "questionmark.circle"
        }
    }

    private var kindColor: Color {
        switch device.kind {
        case .mouse: return .blue
        case .builtInTrackpad, .externalTrackpad: return .green
        case .touchSurface: return .purple
        case .unknown: return .gray
        }
    }
}
