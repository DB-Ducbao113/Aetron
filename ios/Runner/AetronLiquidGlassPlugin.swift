import Flutter
import UIKit

/// The Flutter engine registers the platform view once. Every visible control
/// uses Apple's actual iOS 26 glass material, not a Flutter blur.
final class AetronLiquidGlassPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "aetron/liquid_glass", binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { call, result in
            guard call.method == "isAvailable" else {
                result(FlutterMethodNotImplemented)
                return
            }
            if #available(iOS 26.0, *) { result(true) } else { result(false) }
        }
        registrar.register(GlassControlFactory(messenger: registrar.messenger()), withId: "aetron/liquid_glass/control")
    }
}

private final class GlassControlFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        GlassPlatformControl(frame: frame, id: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger)
    }
}

private final class GlassPlatformControl: NSObject, FlutterPlatformView {
    private let root: UIView
    private let channel: FlutterMethodChannel
    init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "aetron/liquid_glass/\(id)", binaryMessenger: messenger)
        self.channel = channel
        if #available(iOS 26.0, *) {
            let control = GlassControlView(frame: frame, properties: arguments)
            control.onTap = { index in channel.invokeMethod("tap", arguments: index) }
            root = control
        } else {
            root = UIView(frame: frame)
        }
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
            if #available(iOS 26.0, *),
               let control = self?.root as? GlassControlView,
               let properties = call.arguments as? [String: Any] {
                control.update(properties)
            }
            result(nil)
        }
    }
    func view() -> UIView { root }
    deinit { channel.setMethodCallHandler(nil) }
}

/// A lightweight optical rim layered over the system glass. UIKit still owns
/// the actual refraction/material; these strokes only make the Fresnel/glare
/// cues perceptible on Aetron's mostly light backgrounds.
private final class GlassOpticalRimView: UIView {
    private let highlight = CAGradientLayer()
    private let highlightMask = CAShapeLayer()
    private let dispersion = CAGradientLayer()
    private let dispersionMask = CAShapeLayer()
    private let darkEdge = CAGradientLayer()
    private let darkEdgeMask = CAShapeLayer()
    private var isDarkAppearance = false
    private var emphasized = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false

        highlight.startPoint = CGPoint(x: 0.08, y: 0.05)
        highlight.endPoint = CGPoint(x: 0.92, y: 0.95)
        highlight.mask = highlightMask
        layer.addSublayer(highlight)

        dispersion.startPoint = CGPoint(x: 0.02, y: 0.18)
        dispersion.endPoint = CGPoint(x: 0.98, y: 0.82)
        dispersion.mask = dispersionMask
        layer.addSublayer(dispersion)

        darkEdge.startPoint = CGPoint(x: 0.95, y: 0.15)
        darkEdge.endPoint = CGPoint(x: 0.05, y: 0.85)
        darkEdge.mask = darkEdgeMask
        layer.addSublayer(darkEdge)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(dark: Bool, emphasized: Bool) {
        isDarkAppearance = dark
        self.emphasized = emphasized
        updateColors()
    }

    private func updateColors() {
        let whitePeak: CGFloat = emphasized ? 0.72 : 0.52
        let whiteMid: CGFloat = emphasized ? 0.24 : 0.15
        highlight.colors = [
            UIColor.white.withAlphaComponent(isDarkAppearance ? whitePeak * 0.72 : whitePeak).cgColor,
            UIColor.white.withAlphaComponent(whiteMid).cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(isDarkAppearance ? 0.08 : 0.16).cgColor,
        ]
        highlight.locations = [0, 0.26, 0.62, 1]

        dispersion.colors = [
            UIColor.systemCyan.withAlphaComponent(emphasized ? 0.26 : 0.16).cgColor,
            UIColor.clear.cgColor,
            UIColor.systemBlue.withAlphaComponent(emphasized ? 0.18 : 0.10).cgColor,
        ]
        dispersion.locations = [0, 0.56, 1]

        darkEdge.colors = [
            UIColor.black.withAlphaComponent(isDarkAppearance ? 0.10 : (emphasized ? 0.16 : 0.11)).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
        ]
        darkEdge.locations = [0, 0.30, 1]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlight.frame = bounds
        dispersion.frame = bounds
        darkEdge.frame = bounds
        let radius = bounds.height / 2
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.6, dy: 0.6), cornerRadius: max(0, radius - 0.6)).cgPath
        for mask in [highlightMask, dispersionMask, darkEdgeMask] {
            mask.frame = bounds
            mask.path = path
            mask.fillColor = UIColor.clear.cgColor
        }
        highlightMask.strokeColor = UIColor.white.cgColor
        highlightMask.lineWidth = emphasized ? 1.15 : 0.9
        dispersionMask.strokeColor = UIColor.white.cgColor
        dispersionMask.lineWidth = emphasized ? 1.0 : 0.7
        darkEdgeMask.strokeColor = UIColor.white.cgColor
        darkEdgeMask.lineWidth = emphasized ? 1.1 : 0.8
    }
}

/// Paths match the five 24x24 Glassline SVGs, scaled to their 18pt dock size.
/// Template images let UIKit tint the same outline in both selection states.
private enum GlasslineDockIcons {
    static let home = draw(.home)
    static let history = draw(.history)
    static let plus = draw(.plus)
    static let analytics = draw(.analytics)
    static let profile = draw(.profile)
    static let bell = draw(.bell)
    static let gear = draw(.gear)
    static let pin = draw(.pin)

    private enum Shape { case home, history, plus, analytics, profile, bell, gear, pin }

    private static func draw(_ shape: Shape) -> UIImage {
        let size: CGFloat = 18
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { rendererContext in
            let scale = size / 24.0
            rendererContext.cgContext.scaleBy(x: scale, y: scale)
            let path = UIBezierPath()
            func move(_ x: CGFloat, _ y: CGFloat) { path.move(to: CGPoint(x: x, y: y)) }
            func line(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: CGPoint(x: x, y: y)) }

            switch shape {
            case .home:
                // m3 10 9-7 9 7v10H3Z M9 20v-7h6v7
                move(3, 10); line(12, 3); line(21, 10); line(21, 20); line(3, 20)
                path.close()
                move(9, 20); line(9, 13); line(15, 13); line(15, 20)
            case .history:
                // rect x=3 y=4 width=18 height=17 rx=2, plus calendar grid.
                path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 4, width: 18, height: 17), cornerRadius: 2))
                move(7, 2); line(7, 6)
                move(17, 2); line(17, 6)
                move(3, 9); line(21, 9)
                move(7, 13); line(10, 13)
                move(14, 13); line(17, 13)
                move(7, 17); line(10, 17)
            case .plus:
                // M12 5v14M5 12h14 — slightly compact inside the center orb
                move(12, 6); line(12, 18)
                move(6, 12); line(18, 12)
            case .analytics:
                // M4 20V11m5 9V4m5 16v-8m5 8V7
                move(4, 20); line(4, 11)
                move(9, 20); line(9, 4)
                move(14, 20); line(14, 12)
                move(19, 20); line(19, 7)
            case .profile:
                // circle cx=12 cy=8 r=4; M4 21v-2c0-6 16-6 16 0v2
                path.append(UIBezierPath(ovalIn: CGRect(x: 8, y: 4, width: 8, height: 8)))
                move(4, 21); line(4, 19)
                path.addCurve(to: CGPoint(x: 20, y: 19),
                              controlPoint1: CGPoint(x: 4, y: 13),
                              controlPoint2: CGPoint(x: 20, y: 13))
                line(20, 21)
            case .bell:
                // M18 8a6 6 0 0 0-12 0c0 7-3 8-3 10h18c0-2-3-3-3-10ZM10 21h4
                move(18, 8)
                path.addArc(withCenter: CGPoint(x: 12, y: 8),
                            radius: 6,
                            startAngle: 0,
                            endAngle: .pi,
                            clockwise: false)
                path.addCurve(to: CGPoint(x: 3, y: 18),
                              controlPoint1: CGPoint(x: 6, y: 15),
                              controlPoint2: CGPoint(x: 3, y: 16))
                line(21, 18)
                path.addCurve(to: CGPoint(x: 18, y: 8),
                              controlPoint1: CGPoint(x: 21, y: 16),
                              controlPoint2: CGPoint(x: 18, y: 15))
                path.close()
                move(10, 21); line(14, 21)
            case .gear:
                // circle cx=12 cy=12 r=3; m12 2 2 3 4-1 1 4 3 2-2 4 1 4-4 1-2 3-4-2-4 1-1-4-3-2 2-4-1-4 4-1Z
                path.append(UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 6, height: 6)))
                move(12, 2); line(14, 5); line(18, 4); line(19, 8); line(22, 10)
                line(20, 14); line(21, 18); line(17, 19); line(15, 22); line(11, 20)
                line(7, 21); line(6, 17); line(3, 15); line(5, 11); line(4, 7)
                line(8, 6); path.close()
            case .pin:
                // M12 22s8-8 8-13a8 8 0 0 0-16 0c0 5 8 13 8 13Z; circle cx=12 cy=9 r=3
                path.append(UIBezierPath(ovalIn: CGRect(x: 9, y: 6, width: 6, height: 6)))
                move(12, 22)
                path.addCurve(to: CGPoint(x: 20, y: 9),
                              controlPoint1: CGPoint(x: 16, y: 18),
                              controlPoint2: CGPoint(x: 20, y: 14))
                path.addArc(withCenter: CGPoint(x: 12, y: 9),
                            radius: 8,
                            startAngle: 0,
                            endAngle: .pi,
                            clockwise: false)
                path.addCurve(to: CGPoint(x: 12, y: 22),
                              controlPoint1: CGPoint(x: 4, y: 14),
                              controlPoint2: CGPoint(x: 8, y: 18))
                path.close()
            }
            path.lineWidth = shape == .plus ? 2.0 : 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// The 35pt orb retains a minimum 44pt touch target without enlarging its art.
private final class GlasslineRecordButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let horizontal = max(0, (44 - bounds.width) / 2)
        let vertical = max(0, (44 - bounds.height) / 2)
        return bounds.insetBy(dx: -horizontal, dy: -vertical).contains(point)
    }
}

@available(iOS 26.0, *)
private final class GlassControlView: UIView {
    private struct DockTabSlotViews {
        let iconView: UIImageView
        let titleLabel: UILabel
        let bottomConstraint: NSLayoutConstraint
    }

    var onTap: ((Int) -> Void)?
    private let kind: String
    // Liquid Glass needs a container when multiple glass elements share the
    // same functional layer. This lets UIKit render them as one optical scene
    // and morph/merge nearby lenses instead of stacking unrelated blurs.
    private let glassContainer = UIVisualEffectView()
    private let glass = UIVisualEffectView()
    private let opticalRim = GlassOpticalRimView()
    private let stack = UIStackView()
    private let selection = UIVisualEffectView()
    private let selectionRim = GlassOpticalRimView()
    private let recordButton = GlasslineRecordButton(type: .system)
    private let recordGlass = UIVisualEffectView()
    private let recordRim = GlassOpticalRimView()
    private let recordCaption = UILabel()
    private var dockTabViews: [Int: DockTabSlotViews] = [:]
    private var recordWidthConstraint: NSLayoutConstraint?
    private var recordHeightConstraint: NSLayoutConstraint?
    private var recordBottomConstraint: NSLayoutConstraint?
    private var previewIndex: Int?
    private var selectionAnimator: UIViewPropertyAnimator?
    private var selectionBounds = CGRect.zero
    private var buttons: [UIButton] = []
    private let indices = [0, 2, 1, 3, 4]
    private var selected = 0
    private var accent = UIColor.systemBlue
    private var foreground = UIColor.label
    private var dark = false
    private var reducedMotion = false
    private var lastProperties: [String: Any] = [:]

    init(frame: CGRect, properties: [String: Any]) {
        kind = properties["kind"] as? String ?? "button"
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        if kind == "dock" || kind == "segmented" {
            let containerEffect = UIGlassContainerEffect()
            containerEffect.spacing = 8
            glassContainer.effect = containerEffect
            glassContainer.isUserInteractionEnabled = true
            addSubview(glassContainer)

            // Use clear glass for compact navigation controls so underlying
            // content remains visible and the refractive rim is perceptible.
            // Regular glass over Aetron's pale surfaces reads as an opaque
            // white pill and hides the very effect we are trying to expose.
            let effect = UIGlassEffect(style: .clear)
            effect.isInteractive = true
            effect.tintColor = UIColor.white.withAlphaComponent(dark ? 0.035 : 0.018)
            glass.effect = effect
            glass.cornerConfiguration = .capsule()
            glassContainer.contentView.addSubview(glass)

            opticalRim.isUserInteractionEnabled = false
            glassContainer.contentView.addSubview(opticalRim)

            // The selected item is a second native glass lens rendered by the
            // same container. Clear glass keeps the underlying content visible
            // while UIKit supplies the curved rim/refraction interaction.
            let selectionEffect = UIGlassEffect(style: .clear)
            selectionEffect.isInteractive = false
            selection.effect = selectionEffect
            selection.cornerConfiguration = .capsule()
            selection.isUserInteractionEnabled = false
            glassContainer.contentView.addSubview(selection)
            selectionRim.frame = selection.contentView.bounds
            selectionRim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            selectionRim.isUserInteractionEnabled = false
            selection.contentView.addSubview(selectionRim)

            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillEqually
            glassContainer.contentView.addSubview(stack)
            if kind == "dock" {
                for index in indices {
                    let button = index == 1 ? recordButton : UIButton(type: .system)
                    button.tag = index
                    button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                    addPressFeedback(button)
                    if index == 1 {
                        let slot = UIView()
                        let orbEffect = UIGlassEffect(style: .clear)
                        orbEffect.isInteractive = false
                        recordGlass.effect = orbEffect
                        recordGlass.cornerConfiguration = .capsule()
                        recordGlass.isUserInteractionEnabled = false
                        recordGlass.translatesAutoresizingMaskIntoConstraints = false
                        slot.addSubview(recordGlass)
                        recordRim.frame = recordGlass.contentView.bounds
                        recordRim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        recordGlass.contentView.addSubview(recordRim)

                        button.translatesAutoresizingMaskIntoConstraints = false
                        slot.addSubview(button)
                        recordCaption.font = .systemFont(ofSize: 9.0, weight: .medium)
                        recordCaption.textAlignment = .center
                        recordCaption.adjustsFontSizeToFitWidth = true
                        recordCaption.minimumScaleFactor = 0.82
                        recordCaption.isUserInteractionEnabled = false
                        recordCaption.isAccessibilityElement = false
                        recordCaption.translatesAutoresizingMaskIntoConstraints = false
                        slot.addSubview(recordCaption)

                        let wConstraint = button.widthAnchor.constraint(equalToConstant: 32)
                        let hConstraint = button.heightAnchor.constraint(equalToConstant: 32)
                        let bottomConstraint = recordCaption.bottomAnchor.constraint(equalTo: slot.bottomAnchor, constant: -5.0)
                        recordWidthConstraint = wConstraint
                        recordHeightConstraint = hConstraint
                        recordBottomConstraint = bottomConstraint

                        NSLayoutConstraint.activate([
                            button.centerXAnchor.constraint(equalTo: slot.centerXAnchor),
                            wConstraint,
                            hConstraint,
                            button.bottomAnchor.constraint(equalTo: recordCaption.topAnchor, constant: -2.0),
                            recordGlass.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                            recordGlass.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                            recordGlass.widthAnchor.constraint(equalTo: button.widthAnchor),
                            recordGlass.heightAnchor.constraint(equalTo: button.heightAnchor),
                            recordCaption.centerXAnchor.constraint(equalTo: slot.centerXAnchor),
                            recordCaption.leadingAnchor.constraint(greaterThanOrEqualTo: slot.leadingAnchor, constant: 1),
                            recordCaption.trailingAnchor.constraint(lessThanOrEqualTo: slot.trailingAnchor, constant: -1),
                            bottomConstraint,
                        ])
                        stack.addArrangedSubview(slot)
                    } else {
                        let iconView = UIImageView()
                        iconView.contentMode = .scaleAspectFit
                        iconView.isUserInteractionEnabled = false
                        iconView.isAccessibilityElement = false
                        iconView.translatesAutoresizingMaskIntoConstraints = false

                        let titleLabel = UILabel()
                        titleLabel.font = .systemFont(ofSize: 9.5, weight: .semibold)
                        titleLabel.textAlignment = .center
                        titleLabel.lineBreakMode = .byTruncatingTail
                        titleLabel.adjustsFontSizeToFitWidth = true
                        titleLabel.minimumScaleFactor = 0.82
                        titleLabel.isUserInteractionEnabled = false
                        titleLabel.isAccessibilityElement = false
                        titleLabel.translatesAutoresizingMaskIntoConstraints = false

                        button.addSubview(iconView)
                        button.addSubview(titleLabel)
                        let bottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -7.0)
                        NSLayoutConstraint.activate([
                            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                            iconView.widthAnchor.constraint(equalToConstant: 18),
                            iconView.heightAnchor.constraint(equalToConstant: 18),
                            iconView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -3.0),
                            titleLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 2),
                            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -2),
                            bottomConstraint,
                        ])
                        dockTabViews[index] = DockTabSlotViews(
                            iconView: iconView,
                            titleLabel: titleLabel,
                            bottomConstraint: bottomConstraint
                        )
                        stack.addArrangedSubview(button)
                    }
                    buttons.append(button)
                }
            } else {
                let labels = (properties["labels"] as? String ?? "One|Two").components(separatedBy: "|")
                for index in labels.indices {
                    let button = UIButton(type: .system)
                    button.tag = index
                    button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                    addPressFeedback(button)
                    stack.addArrangedSubview(button)
                    buttons.append(button)
                }
            }

            let drag = UIPanGestureRecognizer(target: self, action: #selector(dragSelection(_:)))
            drag.cancelsTouchesInView = true
            glassContainer.addGestureRecognizer(drag)
        } else {
            let containerEffect = UIGlassContainerEffect()
            glassContainer.effect = containerEffect
            glassContainer.isUserInteractionEnabled = true
            glassContainer.frame = bounds
            glassContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(glassContainer)

            let effect = UIGlassEffect(style: .clear)
            effect.isInteractive = true
            glass.effect = effect
            glass.cornerConfiguration = .capsule()
            glass.frame = bounds
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            glassContainer.contentView.addSubview(glass)

            opticalRim.frame = bounds
            opticalRim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            opticalRim.isUserInteractionEnabled = false
            glassContainer.contentView.addSubview(opticalRim)

            let button = UIButton(type: .system)
            button.frame = bounds
            button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addPressFeedback(button)
            glassContainer.contentView.addSubview(button)
            buttons = [button]
        }
        update(properties)
        NSLog(
            "[LiquidGlass] native %@ created; reduceTransparency=%@ increaseContrast=%@ reduceMotion=%@",
            kind,
            UIAccessibility.isReduceTransparencyEnabled ? "true" : "false",
            UIAccessibility.isDarkerSystemColorsEnabled ? "true" : "false",
            UIAccessibility.isReduceMotionEnabled ? "true" : "false"
        )
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func color(_ value: Any?, fallback: UIColor) -> UIColor {
        guard let number = value as? NSNumber else { return fallback }
        let v = number.uint32Value
        return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                       blue: CGFloat(v & 255) / 255, alpha: CGFloat((v >> 24) & 255) / 255)
    }
    func update(_ properties: [String: Any]) {
        if NSDictionary(dictionary: lastProperties).isEqual(to: properties) { return }
        let previous = selected
        lastProperties = properties
        dark = properties["dark"] as? Bool ?? false
        overrideUserInterfaceStyle = dark ? .dark : .light
        opticalRim.configure(dark: dark, emphasized: false)
        selectionRim.configure(dark: dark, emphasized: true)
        accent = color(properties["accent"], fallback: .systemBlue)
        foreground = color(properties["foreground"], fallback: .label)
        reducedMotion = properties["reduceMotion"] as? Bool ?? false
        selected = properties["selected"] as? Int ?? 0
        if kind == "dock" {
            let dockEffect = UIGlassEffect(style: .clear)
            dockEffect.isInteractive = true
            dockEffect.tintColor = dark
                ? UIColor(red: 0.14, green: 0.25, blue: 0.40, alpha: 0.30)
                : UIColor.white.withAlphaComponent(0.32)
            glass.effect = dockEffect

            let labels = (properties["labels"] as? String ?? "Home|History|Record|Analytics|Profile").components(separatedBy: "|")
            let icons = [GlasslineDockIcons.home, GlasslineDockIcons.history,
                         GlasslineDockIcons.plus, GlasslineDockIcons.analytics, GlasslineDockIcons.profile]
            for (position, button) in buttons.enumerated() {
                if button.tag == 1 { continue }
                let active = button.tag == selected
                let label = position < labels.count ? labels[position] : ""
                let tint = active ? accent : foreground.withAlphaComponent(dark ? 0.78 : 0.65)
                if let views = dockTabViews[button.tag] {
                    views.iconView.image = icons[position]
                    views.iconView.tintColor = tint
                    views.titleLabel.text = label
                    views.titleLabel.textColor = tint
                    views.titleLabel.font = UIFont.systemFont(
                        ofSize: currentDockFontSize(),
                        weight: active ? .bold : .semibold
                    )
                }
                button.accessibilityLabel = label
                // Selection is drawn by a single moving glass lens. Letting
                // UIButton also style its selected state adds a second blue fill.
                button.isSelected = false
                button.accessibilityTraits = active ? [.button, .selected] : [.button]
            }
            let orbEffect = UIGlassEffect(style: .clear)
            orbEffect.isInteractive = false
            orbEffect.tintColor = dark
                ? UIColor(red: 0.45, green: 0.68, blue: 0.96, alpha: selected == 1 ? 0.34 : 0.22)
                : UIColor.white.withAlphaComponent(selected == 1 ? 0.62 : 0.42)
            recordGlass.effect = orbEffect

            var recordConfiguration: UIButton.Configuration = .plain()
            recordConfiguration.cornerStyle = .capsule
            recordConfiguration.image = GlasslineDockIcons.plus
            recordConfiguration.baseForegroundColor = dark ? UIColor(red: 0.714, green: 0.847, blue: 1, alpha: 1) : accent
            recordConfiguration.contentInsets = .zero
            recordButton.configuration = recordConfiguration
            recordButton.accessibilityLabel = labels.count > 2 ? labels[2] : "Record"
            recordButton.isSelected = false
            recordButton.accessibilityTraits = selected == 1 ? [.button, .selected] : [.button]
            recordCaption.text = recordButton.accessibilityLabel
            recordCaption.textColor = selected == 1 ? accent : foreground.withAlphaComponent(dark ? 0.78 : 0.65)
            recordCaption.font = .systemFont(
                ofSize: currentDockFontSize(),
                weight: selected == 1 ? .bold : .semibold
            )
            recordRim.configure(dark: dark, emphasized: true)
            let lens = UIGlassEffect(style: .clear)
            lens.isInteractive = false
            lens.tintColor = dark
                ? UIColor(red: 0.57, green: 0.77, blue: 0.97, alpha: 0.22)
                : UIColor.white.withAlphaComponent(0.55)
            selection.effect = lens
            if previous != selected { moveSelection(animated: true) }
            else if selectionBounds != .zero && previewIndex == nil { moveSelection(animated: false) }
            setNeedsLayout()
        } else if kind == "segmented" {
            let labels = (properties["labels"] as? String ?? "").components(separatedBy: "|")
            let symbols = (properties["symbols"] as? String ?? "").components(separatedBy: "|")
            for (index, button) in buttons.enumerated() {
                let active = index == selected
                var configuration: UIButton.Configuration = .plain()
                configuration.cornerStyle = .capsule
                if index < symbols.count, !symbols[index].isEmpty {
                    configuration.image = UIImage(
                        systemName: symbols[index],
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: active ? .semibold : .medium)
                    )
                    configuration.imagePlacement = .leading
                    configuration.imagePadding = 4
                }
                configuration.baseForegroundColor = active ? accent : foreground.withAlphaComponent(dark ? 0.72 : 0.62)
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5)
                let label = index < labels.count ? labels[index] : ""
                var title = AttributedString(label)
                title.font = UIFont.systemFont(ofSize: 11, weight: active ? .semibold : .medium)
                configuration.attributedTitle = title
                configuration.titleLineBreakMode = .byTruncatingTail
                button.configuration = configuration
                button.accessibilityLabel = label
                button.accessibilityTraits = active ? [.button, .selected] : [.button]
                button.isSelected = false
            }
            let lens = UIGlassEffect(style: .clear)
            lens.isInteractive = false
            lens.tintColor = accent.withAlphaComponent(dark ? 0.16 : 0.10)
            selection.effect = lens
            if previous != selected { moveSelection(animated: true) }
            else if selectionBounds != .zero && previewIndex == nil { moveSelection(animated: false) }
            setNeedsLayout()
        } else if kind == "action", let button = buttons.first {
            let prominent = properties["prominent"] as? Bool ?? false
            let destructive = properties["destructive"] as? Bool ?? false
            let enabled = properties["enabled"] as? Bool ?? true
            // Clear variants expose more of the background and make the optical
            // edge obvious over maps/media; prominent actions retain tint.
            var configuration: UIButton.Configuration = prominent ? .prominentClearGlass() : .clearGlass()
            configuration.cornerStyle = .capsule
            let label = properties["label"] as? String ?? ""
            var title = AttributedString(label)
            title.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
            configuration.attributedTitle = title
            if let symbol = properties["symbol"] as? String, !symbol.isEmpty {
                configuration.image = UIImage(
                    systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
                )
                configuration.imagePlacement = .leading
                configuration.imagePadding = 5
            }
            configuration.baseForegroundColor = prominent ? UIColor.white : (destructive ? UIColor.systemRed : foreground)
            if prominent {
                configuration.baseBackgroundColor = destructive ? UIColor.systemRed : accent
            }
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
            button.configuration = configuration
            button.isEnabled = enabled
            button.accessibilityLabel = label
            button.accessibilityTraits = [.button]
            opticalRim.configure(dark: dark, emphasized: prominent)
        } else if let button = buttons.first {
            let active = properties["active"] as? Bool ?? false
            let buttonEffect = UIGlassEffect(style: .clear)
            buttonEffect.isInteractive = true
            buttonEffect.tintColor = active
                ? accent.withAlphaComponent(0.22)
                : UIColor.white.withAlphaComponent(dark ? 0.08 : 0.34)
            glass.effect = buttonEffect

            var configuration: UIButton.Configuration = .plain()
            configuration.cornerStyle = .capsule
            let symbol = properties["symbol"] as? String ?? "circle"
            let iconImage: UIImage?
            switch symbol {
            case "bell":
                iconImage = GlasslineDockIcons.bell
            case "person.crop.circle":
                iconImage = GlasslineDockIcons.profile
            case "gearshape":
                iconImage = GlasslineDockIcons.gear
            case "mappin.and.ellipse":
                iconImage = GlasslineDockIcons.pin
            case "chart.bar":
                iconImage = GlasslineDockIcons.analytics
            default:
                iconImage = UIImage(
                    systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: CGFloat(properties["iconSize"] as? Double ?? 17),
                        weight: .regular
                    )
                )
            }
            configuration.image = iconImage
            configuration.baseForegroundColor = active ? accent : foreground
            configuration.contentInsets = .zero
            button.configuration = configuration
            button.accessibilityLabel = properties["label"] as? String
            button.accessibilityTraits = active ? [.button, .selected] : [.button]
            button.isSelected = active
            opticalRim.configure(dark: dark, emphasized: active)
        }
    }
    private var allowsMotion: Bool { !reducedMotion && !UIAccessibility.isReduceMotionEnabled }

    private func currentDockFontSize() -> CGFloat {
        if bounds.width <= 0 { return 9.5 }
        if bounds.width < 345 { return 8.8 }
        if bounds.width < 370 { return 9.2 }
        return 9.5
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if kind == "dock" || kind == "segmented" {
            glassContainer.frame = bounds
            glass.frame = bounds
            opticalRim.frame = glass.frame
            let dx: CGFloat = kind == "dock" ? (bounds.width >= 380 ? 5 : 3.5) : 2
            let dy: CGFloat = kind == "dock" ? 3 : 2
            stack.frame = glass.frame.insetBy(dx: dx, dy: dy)
            if kind == "dock", bounds.height > 0 {
                // Keep all 5 dock labels on one exact horizontal baseline and
                // size the center "+" orb so it sits cleanly inside the capsule.
                let orbSize: CGFloat = bounds.height >= 60 ? 27 : (bounds.height >= 58 ? 26 : 24)
                let labelBottom: CGFloat = bounds.height >= 60 ? 7.5 : (bounds.height >= 58 ? 6.5 : 5.5)
                recordWidthConstraint?.constant = orbSize
                recordHeightConstraint?.constant = orbSize
                recordBottomConstraint?.constant = -labelBottom
                let fontSize = currentDockFontSize()
                for (tag, views) in dockTabViews {
                    views.bottomConstraint.constant = -labelBottom
                    views.titleLabel.font = UIFont.systemFont(
                        ofSize: fontSize,
                        weight: tag == selected ? .bold : .semibold
                    )
                }
                recordCaption.font = .systemFont(
                    ofSize: fontSize,
                    weight: selected == 1 ? .bold : .semibold
                )
            }
            stack.layoutIfNeeded()
            // Do not snap an in-flight spring to its endpoint on unrelated layout passes.
            if selectionBounds != stack.frame {
                selectionBounds = stack.frame
                moveSelection(animated: false)
            }
        } else {
            glassContainer.frame = bounds
            glass.frame = bounds
            glass.layer.cornerRadius = bounds.height / 2
            glass.clipsToBounds = true
            opticalRim.frame = bounds
            opticalRim.layer.cornerRadius = bounds.height / 2
            opticalRim.clipsToBounds = true
            if let button = buttons.first {
                button.frame = bounds
            }
        }
    }
    private var selectionIndices: [Int] {
        kind == "dock" ? indices : Array(buttons.indices)
    }
    private func targetFrame(_ index: Int) -> CGRect? {
        if kind == "dock" && index == 1 {
            return recordGlass.convert(recordGlass.bounds, to: glassContainer.contentView)
        }
        guard let position = selectionIndices.firstIndex(of: index), stack.arrangedSubviews.indices.contains(position) else { return nil }
        let slot = stack.arrangedSubviews[position]
        let inset: CGFloat = kind == "dock" ? 1.0 : 2.0
        return slot.convert(slot.bounds, to: glassContainer.contentView).insetBy(dx: inset, dy: inset)
    }
    private func interruptSelectionAnimation() {
        guard let animator = selectionAnimator else { return }
        let visibleFrame = selection.layer.presentation()?.frame
        let visibleAlpha = selection.layer.presentation()?.opacity
        animator.stopAnimation(true)
        selectionAnimator = nil
        if let visibleFrame { selection.frame = visibleFrame }
        if let visibleAlpha { selection.alpha = CGFloat(visibleAlpha) }
    }
    private func moveSelection(animated: Bool, targetIndex: Int? = nil) {
        let index = targetIndex ?? previewIndex ?? selected
        guard let frame = targetFrame(index), frame.width > 0 else {
            selectionAnimator?.stopAnimation(true)
            selectionAnimator = nil
            selection.alpha = 0
            return
        }
        interruptSelectionAnimation()
        if !animated || !allowsMotion || window == nil || selection.frame.isEmpty {
            selection.layer.removeAllAnimations()
            UIView.performWithoutAnimation {
                self.selection.frame = frame
                self.selection.layer.cornerRadius = frame.height / 2
                self.selection.alpha = 1
            }
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.44, dampingRatio: 0.76) {
            self.selection.frame = frame
            self.selection.layer.cornerRadius = frame.height / 2
            self.selection.alpha = 1
        }
        selectionAnimator = animator
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self = self, self.selectionAnimator === animator else { return }
            self.selectionAnimator = nil
        }
        animator.startAnimation()
    }
    @objc private func dragSelection(_ gesture: UIPanGestureRecognizer) {
        guard kind == "dock" || kind == "segmented" else { return }
        let x = gesture.location(in: stack).x
        let availableIndices = selectionIndices
        let width = stack.bounds.width / CGFloat(availableIndices.count)
        guard width > 0 else { return }
        let position = max(0, min(availableIndices.count-1, Int(floor(x/width))))
        let next = availableIndices[position]
        switch gesture.state {
        case .began, .changed:
            if previewIndex != next {
                previewIndex = next
                UISelectionFeedbackGenerator().selectionChanged()
            }
            if allowsMotion, let frame = targetFrame(next) {
                interruptSelectionAnimation()
                let localX = gesture.location(in: glassContainer.contentView).x
                let left = stack.frame.minX + 2
                let right = max(left, stack.frame.maxX - frame.width - 2)
                var following = frame
                following.origin.x = min(right, max(left, localX - frame.width / 2))
                selection.frame = following
                selection.layer.cornerRadius = following.height / 2
                selection.alpha = 1
            } else {
                moveSelection(animated: false)
            }
        case .ended:
            previewIndex = nil
            moveSelection(animated: true, targetIndex: next)
            if selected != next { onTap?(next) }
        case .cancelled, .failed:
            previewIndex = nil
            moveSelection(animated: true)
        default: break
        }
    }
    private func addPressFeedback(_ button: UIButton) {
        button.addTarget(self, action: #selector(pressDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(pressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    @objc private func pressDown(_ sender: UIButton) {
        guard allowsMotion else { return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
            sender.transform = CGAffineTransform(scaleX: 0.91, y: 0.91)
            if sender === self.recordButton {
                self.recordGlass.transform = sender.transform
            }
        }
    }
    @objc private func pressUp(_ sender: UIButton) {
        guard allowsMotion else {
            sender.transform = .identity
            if sender === recordButton { recordGlass.transform = .identity }
            return
        }
        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.56, initialSpringVelocity: 0.5,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            sender.transform = .identity
            if sender === self.recordButton {
                self.recordGlass.transform = .identity
            }
        }
    }
    @objc private func tapped(_ sender: UIButton) {
        if (kind == "dock" || kind == "segmented") && sender.tag == selected { return }
        UISelectionFeedbackGenerator().selectionChanged()
        onTap?(sender.tag)
    }
}
