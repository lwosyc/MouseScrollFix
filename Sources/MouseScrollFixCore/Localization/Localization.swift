import Foundation

/// Language preference. `.system` follows the OS language list.
public enum AppLanguage: String, Sendable, CaseIterable, Equatable, Hashable {
    case system
    case english
    case russian

    public var displayName: String {
        switch self {
        case .system: return Localization.currentIsRussian ? "Как в системе" : "System"
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

/// The language actually used for rendering.
public enum ResolvedLanguage: String, Sendable, CaseIterable, Equatable, Hashable {
    case english
    case russian

    /// BCP-47 tag, handy for anything that needs it later.
    public var code: String {
        switch self {
        case .english: return "en"
        case .russian: return "ru"
        }
    }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

/// Every user-visible string in the app.
///
/// Kept as an enum so a missing translation is a test failure rather than a blank
/// label: `LocalizationTests` asserts both tables cover every case.
public enum TextKey: String, CaseIterable, Sendable, Hashable {
    // Menu bar
    case appName
    case menuStatusFormat
    case menuMouseScrollingFormat
    case menuTrackpadNaturalFormat
    case menuDetectedFormat
    case valueOn
    case valueOff
    case menuGrantPermission
    case menuRetryFilter
    case menuEnable
    case menuDisable
    case menuInvertVertical
    case menuInvertHorizontal
    case menuLaunchAtLogin
    case menuOpenSettings
    case menuDiagnostics
    case menuPermissions
    case menuQuit
    case menuTooltip

    // Status
    case statusActive
    case statusOff
    case statusPausedByMac
    case statusPermissionRequired
    case statusNeedsAttention
    case statusStarting
    case statusDetailFiltering
    case statusDetailPaused
    case statusDetailPermission
    case statusDetailTapFailed
    case statusDetailStarting

    // Tabs
    case tabGeneral
    case tabDevices
    case tabDiagnostics
    case tabAbout

    // Settings — mouse
    case sectionMouseScrolling
    case toggleInvertMouse
    case toggleInvertVertical
    case toggleInvertHorizontal

    // Settings — devices
    case sectionDeviceHandling
    case toggleAutomaticDetection
    case pickerAmbiguousPixel
    case pickerTouchSurface
    case pickerInjectedEvents
    case optTreatAsMouse
    case optPassThrough
    case optKeepNatural
    case optInvertAsMouse

    // Settings — system
    case sectionSystem
    case labelNaturalScrolling
    case valueNaturalOn
    case valueNaturalOff
    case toggleLaunchAtLogin
    case noteLaunchAtLogin
    case pickerLanguage

    // Devices pane
    case devicesTitle
    case devicesRefresh
    case devicesEmpty
    case devicesFooter
    case devicesPermissionWarning
    case buttonOpenSettings
    case kindMouse
    case kindBuiltInTrackpad
    case kindTrackpad
    case kindTouchSurface
    case kindUnknown
    case labelBuiltIn
    case labelVirtual

    // Diagnostics
    case sectionRuntime
    case labelFilterState
    case labelAccessibility
    case valueGranted
    case valueMissing
    case labelEventTaps
    case noTapRegistered
    case tapSummaryFormat
    case sectionCounters
    case labelEventsSeen
    case labelInverted
    case labelPassedThrough
    case labelOwnSynthetic
    case labelTapTimeout
    case labelTapUserInput
    case labelTapRecreated
    case labelClassifierResets
    case buttonResetCounters
    case buttonReinstallFilter
    case sectionTrace
    case toggleRecordTrace
    case noteTrace
    case buttonSaveTrace
    case buttonClear
    case recordsFormat
    case traceSavedFormat
    case traceSaveFailedFormat
    case sectionOtherTaps
    case otherTapsNone
    case otherTapsNote

    // About
    case aboutTagline
    case aboutHowItWorksTitle
    case aboutHowItWorksBody
    case aboutPrivacyTitle
    case aboutPrivacyBody

    // Onboarding
    case onboardingTitle
    case onboardingIntro
    case onboardingWhyTitle
    case onboardingWhyBody
    case onboardingStepsTitle
    case onboardingStep1
    case onboardingStep2
    case onboardingStep3
    case onboardingStep4
    case onboardingNotePath
    case onboardingButtonOpenSettings
    case onboardingButtonCheckAgain
    case onboardingButtonLater
    case onboardingGrantedTitle
    case onboardingGrantedBody
    case onboardingButtonDone
    case onboardingReopenHint

    // Misc
    case launchAtLoginFailedFormat
    case languageNote
}

/// Renders `TextKey` values in the resolved language.
///
/// A plain value type with two dictionaries, so the whole localisation layer is pure
/// logic and unit-testable, and works identically when the app runs from a `.app`
/// bundle or straight from `swift run` (no resource bundles involved).
public struct Localization: Sendable, Equatable {
    public let language: ResolvedLanguage

    public init(language: ResolvedLanguage) {
        self.language = language
    }

    public func text(_ key: TextKey) -> String {
        switch language {
        case .english:
            return Localization.english[key] ?? key.rawValue
        case .russian:
            return Localization.russian[key] ?? Localization.english[key] ?? key.rawValue
        }
    }

    /// Fills `{0}`, `{1}`, … placeholders. Avoids `String(format:)` so translators
    /// never have to reason about `%@` and argument ordering.
    public func text(_ key: TextKey, _ arguments: String...) -> String {
        text(key, arguments: arguments)
    }

    /// Array form, so wrappers can forward a variadic list.
    public func text(_ key: TextKey, arguments: [String]) -> String {
        var value = text(key)
        for (index, argument) in arguments.enumerated() {
            value = value.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return value
    }

    public static func resolve(
        preference: AppLanguage,
        preferredLanguages: [String]
    ) -> Localization {
        switch preference {
        case .english:
            return Localization(language: .english)
        case .russian:
            return Localization(language: .russian)
        case .system:
            let first = preferredLanguages.first?.lowercased() ?? "en"
            let isRussian = first.hasPrefix("ru")
            return Localization(language: isRussian ? .russian : .english)
        }
    }

    /// Used for the language picker's own label before a language is chosen.
    public static var currentIsRussian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") ?? false
    }

    public static let english: [TextKey: String] = [
        .appName: "MouseScrollFix",
        .menuStatusFormat: "{0}",
        .menuMouseScrollingFormat: "Mouse scrolling: {0}",
        .menuTrackpadNaturalFormat: "Trackpad natural scrolling: {0} (system)",
        .menuDetectedFormat: "Detected: {0}",
        .valueOn: "ON",
        .valueOff: "OFF",
        .menuGrantPermission: "Grant Accessibility permission…",
        .menuRetryFilter: "Retry filter",
        .menuEnable: "Enable",
        .menuDisable: "Disable",
        .menuInvertVertical: "Invert vertical scrolling",
        .menuInvertHorizontal: "Invert horizontal scrolling",
        .menuLaunchAtLogin: "Launch at Login",
        .menuOpenSettings: "Open Settings…",
        .menuDiagnostics: "Diagnostics…",
        .menuPermissions: "Permissions…",
        .menuQuit: "Quit {0}",
        .menuTooltip: "MouseScrollFix — natural trackpad, classic mouse",

        .statusActive: "Active",
        .statusOff: "Off",
        .statusPausedByMac: "Paused by macOS",
        .statusPermissionRequired: "Permission required",
        .statusNeedsAttention: "Needs attention",
        .statusStarting: "Starting…",
        .statusDetailFiltering: "Scroll events are being filtered.",
        .statusDetailPaused: "macOS disabled the filter. Retry to reinstall it.",
        .statusDetailPermission:
            "MouseScrollFix cannot change scroll direction until Accessibility access is granted.",
        .statusDetailTapFailed: "The filter is not running. Try reinstalling it from Diagnostics.",
        .statusDetailStarting: "Filter not running yet.",

        .tabGeneral: "General",
        .tabDevices: "Devices",
        .tabDiagnostics: "Diagnostics",
        .tabAbout: "About",

        .sectionMouseScrolling: "Mouse scrolling",
        .toggleInvertMouse: "Invert mouse scrolling",
        .toggleInvertVertical: "Invert vertical scrolling",
        .toggleInvertHorizontal: "Invert horizontal scrolling",

        .sectionDeviceHandling: "Device handling",
        .toggleAutomaticDetection: "Automatic mouse detection",
        .pickerAmbiguousPixel: "High-resolution wheel input",
        .pickerTouchSurface: "Touch surface without mayBegin",
        .pickerInjectedEvents: "Events posted by other apps",
        .optTreatAsMouse: "Treat as mouse (invert)",
        .optPassThrough: "Pass through (conservative)",
        .optKeepNatural: "Keep natural (Magic Mouse)",
        .optInvertAsMouse: "Invert as mouse",

        .sectionSystem: "System",
        .labelNaturalScrolling: "Natural scrolling",
        .valueNaturalOn: "on (system)",
        .valueNaturalOff: "off (system)",
        .toggleLaunchAtLogin: "Launch at Login",
        .noteLaunchAtLogin:
            "Login items require the app to be code signed and kept in a stable location. If registration fails, move the app to /Applications and try again.",
        .pickerLanguage: "Language",

        .devicesTitle: "Pointing devices",
        .devicesRefresh: "Refresh",
        .devicesEmpty: "No pointing device reported by the I/O Registry.",
        .devicesFooter:
            "The device list is informational. macOS exposes no documented way to tell which device produced a given scroll event, so direction is decided per scroll stream (gesture phases and delta encoding), not per device. This list feeds two policy inputs: whether an external pointing device exists, and whether only a built-in trackpad is present.",
        .devicesPermissionWarning:
            "Accessibility permission is required to filter scroll events.",
        .buttonOpenSettings: "Open System Settings",
        .kindMouse: "mouse",
        .kindBuiltInTrackpad: "built-in trackpad",
        .kindTrackpad: "trackpad",
        .kindTouchSurface: "touch surface",
        .kindUnknown: "unknown",
        .labelBuiltIn: "built-in",
        .labelVirtual: "virtual",

        .sectionRuntime: "Runtime",
        .labelFilterState: "Filter state",
        .labelAccessibility: "Accessibility",
        .valueGranted: "granted",
        .valueMissing: "missing",
        .labelEventTaps: "Event taps",
        .noTapRegistered: "no tap registered for this process",
        .tapSummaryFormat: "{0} tap(s), avg {1} µs, max {2} µs",
        .sectionCounters: "Counters",
        .labelEventsSeen: "Scroll events seen",
        .labelInverted: "Inverted",
        .labelPassedThrough: "Passed through",
        .labelOwnSynthetic: "Own synthetic events skipped",
        .labelTapTimeout: "Tap disabled by timeout",
        .labelTapUserInput: "Tap disabled by user input",
        .labelTapRecreated: "Tap recreated",
        .labelClassifierResets: "Classifier resets",
        .buttonResetCounters: "Reset counters",
        .buttonReinstallFilter: "Reinstall filter",
        .sectionTrace: "Scroll trace",
        .toggleRecordTrace: "Record scroll stream decisions",
        .noteTrace:
            "Records class, reason and action per scroll event in memory only. No keystrokes, no window titles, nothing leaves the machine.",
        .buttonSaveTrace: "Save trace…",
        .buttonClear: "Clear",
        .recordsFormat: "{0} record(s)",
        .traceSavedFormat: "Saved {0} record(s) to {1}",
        .traceSaveFailedFormat: "Could not save: {0}",
        .sectionOtherTaps: "Other event taps",
        .otherTapsNone: "None",
        .otherTapsNote:
            "Several tools that modify scrolling can fight each other. If a device behaves inconsistently, quit the others and retry.",

        .aboutTagline:
            "Natural scrolling for the trackpad, classic scrolling for every mouse macOS recognises.",
        .aboutHowItWorksTitle: "How it works",
        .aboutHowItWorksBody:
            """
            macOS shares one Natural scrolling preference between mouse and trackpad, and no \
            public API identifies which device produced a scroll event. The app therefore \
            classifies each scroll stream from documented fields (scrollPhase, momentumPhase, \
            isContinuous) and applies the direction that matches the device class.

            A trackpad gesture always keeps its direction for the whole gesture, momentum \
            included. Everything that is not a recognised touch gesture is treated as a mouse. \
            When no external pointing device is present, ambiguous pixel input is left alone so \
            the trackpad can never be inverted by accident.
            """,
        .aboutPrivacyTitle: "Privacy",
        .aboutPrivacyBody:
            "No network access, no analytics, no keyboard logging. The app reads the Natural scrolling preference and never writes it.",

        .onboardingTitle: "MouseScrollFix needs one permission",
        .onboardingIntro:
            "To reverse the mouse wheel while leaving the trackpad natural, the app has to modify scroll events before macOS delivers them to applications. That requires Accessibility access.",
        .onboardingWhyTitle: "What it needs and what it does not",
        .onboardingWhyBody:
            "Accessibility lets the app change scroll direction. It is not used to read text, watch the keyboard, capture the screen, or send anything anywhere. The app has no network code at all, and it never changes your system scroll setting.",
        .onboardingStepsTitle: "How to grant it",
        .onboardingStep1: "1. Click “Open System Settings” below.",
        .onboardingStep2:
            "2. Go to Privacy & Security → Accessibility. On newer macOS this pane may be called “Device Control and Data Access”.",
        .onboardingStep3: "3. Turn on the switch next to MouseScrollFix.",
        .onboardingStep4: "4. Come back here and click “Check again”.",
        .onboardingNotePath:
            "Keep the app in a stable location such as /Applications: rebuilding an unsigned build changes its identity and macOS will ask for permission again.",
        .onboardingButtonOpenSettings: "Open System Settings",
        .onboardingButtonCheckAgain: "Check again",
        .onboardingButtonLater: "Later",
        .onboardingGrantedTitle: "Permission granted",
        .onboardingGrantedBody:
            "The filter is running. Scroll with the mouse and with the trackpad to confirm each behaves the way you want.",
        .onboardingButtonDone: "Done",
        .onboardingReopenHint:
            "You can reopen this window any time from the menu bar: Permissions…",

        .launchAtLoginFailedFormat: "Failed: {0}",
        .languageNote:
            "The app language. “System” follows your macOS language setting."
    ]

    public static let russian: [TextKey: String] = [
        .appName: "MouseScrollFix",
        .menuStatusFormat: "{0}",
        .menuMouseScrollingFormat: "Прокрутка мыши: {0}",
        .menuTrackpadNaturalFormat: "Natural scrolling трекпада: {0} (система)",
        .menuDetectedFormat: "Обнаружено: {0}",
        .valueOn: "ВКЛ",
        .valueOff: "ВЫКЛ",
        .menuGrantPermission: "Выдать разрешение Accessibility…",
        .menuRetryFilter: "Переустановить фильтр",
        .menuEnable: "Включить",
        .menuDisable: "Выключить",
        .menuInvertVertical: "Инвертировать вертикальную прокрутку",
        .menuInvertHorizontal: "Инвертировать горизонтальную прокрутку",
        .menuLaunchAtLogin: "Запускать при входе",
        .menuOpenSettings: "Настройки…",
        .menuDiagnostics: "Диагностика…",
        .menuPermissions: "Разрешения…",
        .menuQuit: "Завершить {0}",
        .menuTooltip: "MouseScrollFix — natural для трекпада, классическая прокрутка мыши",

        .statusActive: "Активно",
        .statusOff: "Выключено",
        .statusPausedByMac: "Приостановлено macOS",
        .statusPermissionRequired: "Нужно разрешение",
        .statusNeedsAttention: "Требует внимания",
        .statusStarting: "Запуск…",
        .statusDetailFiltering: "Фильтр прокрутки работает.",
        .statusDetailPaused: "macOS отключила фильтр. Нажмите «Переустановить фильтр».",
        .statusDetailPermission:
            "Пока не выдано разрешение Accessibility, приложение не может менять направление прокрутки.",
        .statusDetailTapFailed:
            "Фильтр не работает. Переустановите его на вкладке «Диагностика».",
        .statusDetailStarting: "Фильтр ещё не запущен.",

        .tabGeneral: "Основные",
        .tabDevices: "Устройства",
        .tabDiagnostics: "Диагностика",
        .tabAbout: "О программе",

        .sectionMouseScrolling: "Прокрутка мыши",
        .toggleInvertMouse: "Инвертировать прокрутку мыши",
        .toggleInvertVertical: "Инвертировать вертикальную прокрутку",
        .toggleInvertHorizontal: "Инвертировать горизонтальную прокрутку",

        .sectionDeviceHandling: "Обработка устройств",
        .toggleAutomaticDetection: "Автоопределение мыши",
        .pickerAmbiguousPixel: "Колесо высокого разрешения",
        .pickerTouchSurface: "Сенсорная поверхность без mayBegin",
        .pickerInjectedEvents: "События от других приложений",
        .optTreatAsMouse: "Считать мышью (инвертировать)",
        .optPassThrough: "Пропускать без изменений",
        .optKeepNatural: "Оставить natural (Magic Mouse)",
        .optInvertAsMouse: "Инвертировать как мышь",

        .sectionSystem: "Система",
        .labelNaturalScrolling: "Natural scrolling",
        .valueNaturalOn: "включено (система)",
        .valueNaturalOff: "выключено (система)",
        .toggleLaunchAtLogin: "Запускать при входе",
        .noteLaunchAtLogin:
            "Для автозапуска приложение должно быть подписано и лежать в постоянном месте. Если регистрация не удалась, переместите приложение в /Applications и повторите.",
        .pickerLanguage: "Язык",

        .devicesTitle: "Указывающие устройства",
        .devicesRefresh: "Обновить",
        .devicesEmpty: "IORegistry не сообщает ни об одном указывающем устройстве.",
        .devicesFooter:
            "Список устройств носит справочный характер. В macOS нет документированного способа определить, какое устройство породило конкретное событие прокрутки, поэтому направление выбирается для потока событий (по фазам жеста и типу дельт), а не для устройства. Этот список влияет на два решения: есть ли внешнее указывающее устройство и только ли встроенный трекпад присутствует.",
        .devicesPermissionWarning: "Для фильтрации событий прокрутки нужно разрешение Accessibility.",
        .buttonOpenSettings: "Открыть системные настройки",
        .kindMouse: "мышь",
        .kindBuiltInTrackpad: "встроенный трекпад",
        .kindTrackpad: "трекпад",
        .kindTouchSurface: "сенсорная поверхность",
        .kindUnknown: "неизвестно",
        .labelBuiltIn: "встроенное",
        .labelVirtual: "виртуальное",

        .sectionRuntime: "Состояние",
        .labelFilterState: "Состояние фильтра",
        .labelAccessibility: "Accessibility",
        .valueGranted: "выдано",
        .valueMissing: "не выдано",
        .labelEventTaps: "Event tap",
        .noTapRegistered: "для этого процесса tap не зарегистрирован",
        .tapSummaryFormat: "{0} tap, среднее {1} мкс, максимум {2} мкс",
        .sectionCounters: "Счётчики",
        .labelEventsSeen: "Событий прокрутки получено",
        .labelInverted: "Инвертировано",
        .labelPassedThrough: "Пропущено без изменений",
        .labelOwnSynthetic: "Своих синтетических событий пропущено",
        .labelTapTimeout: "Tap отключён по таймауту",
        .labelTapUserInput: "Tap отключён пользователем",
        .labelTapRecreated: "Tap пересоздан",
        .labelClassifierResets: "Сбросов классификатора",
        .buttonResetCounters: "Сбросить счётчики",
        .buttonReinstallFilter: "Переустановить фильтр",
        .sectionTrace: "Трассировка прокрутки",
        .toggleRecordTrace: "Записывать решения по потокам прокрутки",
        .noteTrace:
            "Записывает класс, причину и действие для каждого события — только в памяти. Ни нажатий клавиш, ни заголовков окон, ничего не отправляется наружу.",
        .buttonSaveTrace: "Сохранить трассировку…",
        .buttonClear: "Очистить",
        .recordsFormat: "записей: {0}",
        .traceSavedFormat: "Сохранено записей: {0} → {1}",
        .traceSaveFailedFormat: "Не удалось сохранить: {0}",
        .sectionOtherTaps: "Другие event tap",
        .otherTapsNone: "Нет",
        .otherTapsNote:
            "Несколько утилит, меняющих прокрутку, могут мешать друг другу. Если устройство ведёт себя непоследовательно, закройте остальные и повторите.",

        .aboutTagline:
            "Natural scrolling для трекпада и классическая прокрутка для любой мыши, которую видит macOS.",
        .aboutHowItWorksTitle: "Как это работает",
        .aboutHowItWorksBody:
            """
            В macOS одна общая настройка Natural scrolling для мыши и трекпада, и нет \
            публичного API, которое сообщало бы, какое устройство породило событие прокрутки. \
            Поэтому приложение определяет класс потока событий по документированным полям \
            (scrollPhase, momentumPhase, isContinuous) и применяет направление, \
            соответствующее этому классу.

            Жест на трекпаде сохраняет направление на весь жест, включая инерцию. Всё, что не \
            распознано как сенсорный жест, считается мышью. Если внешней мыши нет, \
            неоднозначный пиксельный ввод не трогается вовсе — так трекпад невозможно \
            инвертировать случайно.
            """,
        .aboutPrivacyTitle: "Приватность",
        .aboutPrivacyBody:
            "Нет доступа к сети, нет аналитики, нет записи клавиатуры. Приложение читает настройку Natural scrolling и никогда её не изменяет.",

        .onboardingTitle: "MouseScrollFix нужно одно разрешение",
        .onboardingIntro:
            "Чтобы разворачивать колесо мыши и при этом не трогать трекпад, приложение должно изменять события прокрутки до того, как macOS отдаст их приложениям. Для этого нужен доступ Accessibility.",
        .onboardingWhyTitle: "Что именно нужно и что не делается",
        .onboardingWhyBody:
            "Accessibility позволяет приложению менять направление прокрутки. Оно не читает текст, не следит за клавиатурой, не захватывает экран и ничего никуда не отправляет. В приложении вообще нет кода для работы с сетью, и оно никогда не меняет системную настройку прокрутки.",
        .onboardingStepsTitle: "Как выдать разрешение",
        .onboardingStep1: "1. Нажмите «Открыть системные настройки» ниже.",
        .onboardingStep2:
            "2. Откройте «Конфиденциальность и безопасность» → «Универсальный доступ» (Accessibility). В новых версиях macOS раздел может называться «Управление устройствами и доступ к данным».",
        .onboardingStep3: "3. Включите переключатель напротив MouseScrollFix.",
        .onboardingStep4: "4. Вернитесь сюда и нажмите «Проверить снова».",
        .onboardingNotePath:
            "Держите приложение в постоянном месте, например /Applications: при пересборке неподписанной сборки меняется её идентичность, и macOS попросит разрешение заново.",
        .onboardingButtonOpenSettings: "Открыть системные настройки",
        .onboardingButtonCheckAgain: "Проверить снова",
        .onboardingButtonLater: "Позже",
        .onboardingGrantedTitle: "Разрешение выдано",
        .onboardingGrantedBody:
            "Фильтр работает. Прокрутите колесом мыши и двумя пальцами по трекпаду — убедитесь, что каждое устройство ведёт себя как нужно.",
        .onboardingButtonDone: "Готово",
        .onboardingReopenHint:
            "Это окно можно открыть в любой момент из меню в строке состояния: «Разрешения…»",

        .launchAtLoginFailedFormat: "Ошибка: {0}",
        .languageNote:
            "Язык интерфейса приложения. «Как в системе» — следовать языку macOS."
    ]
}
