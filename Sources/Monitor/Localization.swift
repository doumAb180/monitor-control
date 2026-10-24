import Foundation

// Stable language codes are persisted independently of translated display names.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", korean = "ko", spanish = "es"
    case chinese = "zh-Hans", japanese = "ja", french = "fr", german = "de"

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .system: return "Follow system"
        case .english: return "English"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            switch identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first {
            case "en": return .english
            case "ko": return .korean
            case "es": return .spanish
            case "zh": return .chinese
            case "ja": return .japanese
            case "fr": return .french
            case "de": return .german
            default: continue
            }
        }
        return .english
    }

    var column: Int {
        switch resolved() {
        case .korean: return 1
        case .spanish: return 2
        case .chinese: return 3
        case .japanese: return 4
        case .french: return 5
        case .german: return 6
        default: return 0
        }
    }
}

// Keep messages as keys and arguments, so already-visible feedback changes language too.
indirect enum LocalizedText {
    case key(String, [LocalizedText] = [])
    case verbatim(String)

    func rendered(in language: AppLanguage) -> String {
        switch self {
        case .verbatim(let value): return value
        case .key(let key, let arguments):
            let template = Localization.catalog[key]?[language.column] ?? key
            // Substitute in a single pass: user text containing {0} is never reinterpreted.
            let parts = template.components(separatedBy: "{")
            return parts.enumerated().map { offset, part in
                guard offset > 0 else { return part }
                guard let end = part.firstIndex(of: "}"),
                      let index = Int(part[..<end]), arguments.indices.contains(index) else { return "{" + part }
                return arguments[index].rendered(in: language) + part[part.index(after: end)...]
            }.joined()
        }
    }
}

enum Localization {
    // English, Korean, Spanish, Simplified Chinese, Japanese, French, German.
    static let catalog: [String: [String]] = [
        "Follow system": ["Follow system", "시스템 설정 따르기", "Usar idioma del sistema", "跟随系统", "システム設定に従う", "Suivre le système", "Systemsprache verwenden"],
        "Language": ["Language", "언어", "Idioma", "语言", "言語", "Langue", "Sprache"],
        "Changes apply immediately and stay saved after restarting Monitor.": ["Changes apply immediately and stay saved after restarting Monitor.", "변경 즉시 적용되며 Monitor를 다시 실행해도 유지됩니다.", "Los cambios se aplican al instante y se conservan al reiniciar Monitor.", "更改立即生效，重启 Monitor 后仍会保留。", "変更はすぐに反映され、Monitor を再起動しても保持されます。", "Les changements sont immédiats et conservés au redémarrage de Monitor.", "Änderungen gelten sofort und bleiben nach einem Neustart von Monitor erhalten."],
        "Make every adjustment yours.": ["Make every adjustment yours.", "작은 차이도, 내 취향대로.", "Cada ajuste, a tu gusto.", "每次调节，都合你意。", "小さな調整も、自分好みに。", "Chaque réglage à votre goût.", "Jede Einstellung nach deinem Geschmack."],
        "Sound just right. Light just enough.": ["Sound just right. Light just enough.", "딱 맞는 소리, 편안한 밝기.", "El sonido justo. La luz adecuada.", "声音恰好，亮度舒适。", "ちょうどいい音、心地よい明るさ。", "Le bon son. La juste lumière.", "Der richtige Klang. Das passende Licht."],
        "Controls": ["Controls", "조절 화면", "Controles", "调节", "調整", "Commandes", "Steuerung"],
        "Settings": ["Settings", "설정", "Ajustes", "设置", "設定", "Réglages", "Einstellungen"],
        "Looking for connected monitors": ["Looking for connected monitors", "연결된 모니터를 찾고 있어요", "Buscando monitores conectados", "正在查找已连接的显示器", "接続されたモニターを検索中", "Recherche des écrans connectés", "Verbundene Monitore werden gesucht"],
        "Monitor": ["Monitor", "모니터", "Monitor", "显示器", "モニター", "Écran", "Monitor"],
        "External display": ["External display", "외부 모니터", "Pantalla externa", "外接显示器", "外部モニター", "Écran externe", "Externer Bildschirm"],
        "Volume": ["Volume", "볼륨", "Volumen", "音量", "音量", "Volume", "Lautstärke"],
        "Brightness": ["Brightness", "밝기", "Brillo", "亮度", "明るさ", "Luminosité", "Helligkeit"],
        "Unmute": ["Unmute", "음소거 해제", "Activar sonido", "取消静音", "ミュート解除", "Réactiver le son", "Ton einschalten"],
        "Mute": ["Mute", "음소거", "Silenciar", "静音", "ミュート", "Couper le son", "Stummschalten"],
        "Scan again": ["Scan again", "다시 검색", "Buscar de nuevo", "重新搜索", "再検索", "Rechercher à nouveau", "Erneut suchen"],
        "Connect your monitor": ["Connect your monitor", "모니터를 연결해 주세요", "Conecta tu monitor", "请连接显示器", "モニターを接続してください", "Connectez votre écran", "Monitor anschließen"],
        "Connect a DDC/CI monitor to your Apple Silicon Mac to control volume and brightness.": ["Connect a DDC/CI monitor to your Apple Silicon Mac to control volume and brightness.", "Apple Silicon Mac에서 DDC/CI를 지원하는 외부 모니터를 연결하면 볼륨과 밝기를 조절할 수 있어요.", "Conecta un monitor DDC/CI a tu Mac con Apple Silicon para ajustar el volumen y el brillo.", "将支持 DDC/CI 的显示器连接到 Apple Silicon Mac，即可调节音量和亮度。", "Apple Silicon Mac に DDC/CI 対応モニターを接続すると、音量と明るさを調整できます。", "Connectez un écran DDC/CI à votre Mac Apple Silicon pour régler le volume et la luminosité.", "Verbinde einen DDC/CI-Monitor mit deinem Apple Silicon Mac, um Lautstärke und Helligkeit zu regeln."],
        "{0} per press": ["{0} per press", "한 번에 {0}씩", "{0} por pulsación", "每次调节 {0}", "1回につき {0}", "{0} par pression", "{0} pro Tastendruck"],
        "Sound, finely tuned": ["Sound, finely tuned", "소리도 섬세하게", "Sonido a tu medida", "声音细腻可调", "音もきめ細かく", "Un son tout en finesse", "Klang fein abgestimmt"],
        "Comfort for your eyes": ["Comfort for your eyes", "눈이 편안한 만큼", "Comodidad para tus ojos", "让眼睛更舒适", "目にやさしい明るさ", "Le confort de vos yeux", "Angenehm für die Augen"],
        "Could not read this control. Check the monitor’s DDC/CI setting and connection.": ["Could not read this control. Check the monitor’s DDC/CI setting and connection.", "이 모니터에서 값을 읽지 못했어요. 모니터의 DDC/CI 설정과 연결을 확인해 주세요.", "No se pudo leer este ajuste. Comprueba la conexión y el ajuste DDC/CI del monitor.", "无法读取此项设置。请检查显示器的 DDC/CI 设置和连接。", "値を読み取れません。モニターの DDC/CI 設定と接続を確認してください。", "Impossible de lire ce réglage. Vérifiez la connexion et le réglage DDC/CI de l’écran.", "Wert konnte nicht gelesen werden. Prüfe die DDC/CI-Einstellung und die Verbindung des Monitors."],
        "Increase {0}": ["Increase {0}", "{0} 높이기", "Subir {0}", "调高{0}", "{0}を上げる", "Augmenter {0}", "{0} erhöhen"],
        "Decrease {0}": ["Decrease {0}", "{0} 낮추기", "Bajar {0}", "调低{0}", "{0}を下げる", "Réduire {0}", "{0} verringern"],
        "MonitorControl is running": ["MonitorControl is running", "MonitorControl이 실행 중이에요", "MonitorControl está en ejecución", "MonitorControl 正在运行", "MonitorControl が起動中です", "MonitorControl est en cours d’exécution", "MonitorControl läuft"],
        "Quit MonitorControl to let Monitor handle your media keys without conflicts.": ["Quit MonitorControl to let Monitor handle your media keys without conflicts.", "키보드 제어가 겹치지 않도록 MonitorControl을 종료하면 Monitor가 볼륨 키를 연결해요.", "Cierra MonitorControl para que Monitor controle las teclas multimedia sin conflictos.", "退出 MonitorControl 后，Monitor 即可接管媒体键，避免冲突。", "キー操作の競合を避けるため、MonitorControl を終了してください。", "Quittez MonitorControl pour que Monitor gère les touches multimédias sans conflit.", "Beende MonitorControl, damit Monitor die Medientasten ohne Konflikte steuern kann."],
        "Better with your keyboard": ["Better with your keyboard", "키보드로 더 편하게", "Más cómodo con el teclado", "键盘操作更方便", "キーボードでもっと便利に", "Plus pratique au clavier", "Bequemer mit der Tastatur"],
        "Enable Monitor in System Settings → Privacy & Security → Accessibility.": ["Enable Monitor in System Settings → Privacy & Security → Accessibility.", "시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Monitor를 허용해 주세요.", "Activa Monitor en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.", "请在系统设置 → 隐私与安全性 → 辅助功能中启用 Monitor。", "システム設定 → プライバシーとセキュリティ → アクセシビリティで Monitor を許可してください。", "Activez Monitor dans Réglages Système → Confidentialité et sécurité → Accessibilité.", "Aktiviere Monitor unter Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen."],
        "Open accessibility settings": ["Open accessibility settings", "손쉬운 사용 설정 열기", "Abrir ajustes de accesibilidad", "打开辅助功能设置", "アクセシビリティ設定を開く", "Ouvrir les réglages d’accessibilité", "Bedienungshilfen öffnen"],
        "Check the keyboard connection": ["Check the keyboard connection", "키보드 연결을 확인해 주세요", "Comprueba la conexión del teclado", "请检查键盘连接", "キーボード接続を確認してください", "Vérifiez la connexion du clavier", "Tastaturverbindung prüfen"],
        "Check Accessibility permission, then restart Monitor. You can use the sliders now.": ["Check Accessibility permission, then restart Monitor. You can use the sliders now.", "손쉬운 사용 권한을 확인한 뒤 Monitor를 다시 실행해 주세요. 슬라이더는 바로 사용할 수 있어요.", "Comprueba el permiso de accesibilidad y reinicia Monitor. Puedes usar los deslizadores ahora.", "请检查辅助功能权限，然后重启 Monitor。滑块可立即使用。", "アクセシビリティの許可を確認し、Monitor を再起動してください。スライダーはすぐに使えます。", "Vérifiez l’autorisation d’accessibilité, puis relancez Monitor. Les curseurs sont déjà utilisables.", "Prüfe die Bedienungshilfen-Berechtigung und starte Monitor neu. Die Regler kannst du bereits nutzen."],
        "Volume keys · {0}": ["Volume keys · {0}", "볼륨 키 · {0}", "Teclas de volumen · {0}", "音量键 · {0}", "音量キー · {0}", "Touches de volume · {0}", "Lautstärketasten · {0}"],
        "Brightness keys · {0}": ["Brightness keys · {0}", "밝기 키 · {0}", "Teclas de brillo · {0}", "亮度键 · {0}", "明るさキー · {0}", "Touches de luminosité · {0}", "Helligkeitstasten · {0}"],
        "Keyboard control is off": ["Keyboard control is off", "키보드 제어 꺼짐", "Control por teclado desactivado", "键盘控制已关闭", "キーボード操作はオフです", "Commande au clavier désactivée", "Tastatursteuerung aus"],
        "Volume adjustment": ["Volume adjustment", "볼륨 조절 방식", "Ajuste de volumen", "音量调节", "音量の調整方法", "Réglage du volume", "Lautstärkeregelung"],
        "Brightness adjustment": ["Brightness adjustment", "밝기 조절 방식", "Ajuste de brillo", "亮度调节", "明るさの調整方法", "Réglage de la luminosité", "Helligkeitsregelung"],
        "Fine": ["Fine", "미세 조절", "Preciso", "精细调节", "微調整", "Précis", "Fein"],
        "Standard": ["Standard", "편의 조절", "Estándar", "常规调节", "標準", "Standard", "Standard"],
        "Exactly 1 per press.": ["Exactly 1 per press.", "모니터의 실제 값을 한 번에 1씩 조절해요.", "Cambia exactamente 1 por pulsación.", "每次按键精确调节 1 个单位。", "1回押すごとに正確に1ずつ調整します。", "Exactement 1 unité par pression.", "Genau 1 Einheit pro Tastendruck."],
        "16 steps across the range, like macOS volume keys.": ["16 steps across the range, like macOS volume keys.", "기존 Mac 볼륨 키처럼 전체 범위를 16단계로 조절해요.", "16 niveles en todo el rango, como las teclas de volumen de macOS.", "像 macOS 音量键一样，将整个范围分为 16 档。", "macOS の音量キーと同じように、全範囲を16段階で調整します。", "16 paliers sur toute la plage, comme les touches de volume de macOS.", "16 Stufen über den gesamten Bereich, wie die macOS-Lautstärketasten."],
        "16 steps": ["16 steps", "16단계 조절", "16 niveles", "16 档", "16段階", "16 paliers", "16 Stufen"],
        "Hold Shift + Option for a 1-unit adjustment in either mode.": ["Hold Shift + Option for a 1-unit adjustment in either mode.", "어떤 모드에서든 Shift + Option을 누르면 1씩 조절해요.", "Mantén Shift + Option para ajustar de 1 en 1 en cualquier modo.", "在任意模式下，按住 Shift + Option 即可每次调节 1 个单位。", "どちらのモードでも Shift + Option を押すと1ずつ調整できます。", "Maintenez Shift + Option pour régler par unité dans les deux modes.", "Halte Shift + Option für Einzelschritte in beiden Modi."],
        "Use keyboard volume keys": ["Use keyboard volume keys", "키보드 볼륨 키 사용", "Usar teclas de volumen", "使用键盘音量键", "キーボードの音量キーを使う", "Utiliser les touches de volume", "Lautstärketasten verwenden"],
        "Use keyboard brightness keys": ["Use keyboard brightness keys", "키보드 밝기 키 사용", "Usar teclas de brillo", "使用键盘亮度键", "キーボードの明るさキーを使う", "Utiliser les touches de luminosité", "Helligkeitstasten verwenden"],
        "Keys control the selected external monitor. Disable brightness keys to keep Mac’s normal brightness control.": ["Keys control the selected external monitor. Disable brightness keys to keep Mac’s normal brightness control.", "선택한 외부 모니터에 적용돼요. 밝기 키를 끄면 Mac의 기본 밝기 조절을 유지해요.", "Las teclas controlan el monitor externo seleccionado. Desactiva las de brillo para mantener el control normal del Mac.", "按键控制所选外接显示器。关闭亮度键可保留 Mac 的默认亮度调节。", "選択した外部モニターを操作します。明るさキーをオフにすると Mac 標準の明るさ調整を維持します。", "Les touches contrôlent l’écran externe sélectionné. Désactivez celles de luminosité pour garder le réglage normal du Mac.", "Die Tasten steuern den ausgewählten externen Monitor. Deaktiviere die Helligkeitstasten für die normale Mac-Steuerung."],
        "Launch at login": ["Launch at login", "로그인할 때 실행", "Abrir al iniciar sesión", "登录时启动", "ログイン時に起動", "Ouvrir à la connexion", "Bei Anmeldung starten"],
        "Small adjustments. Big comfort.": ["Small adjustments. Big comfort.", "작은 조절, 큰 편안함.", "Pequeños ajustes. Gran comodidad.", "细微调节，舒适加倍。", "小さな調整、大きな心地よさ。", "Petits réglages. Grand confort.", "Kleine Änderungen. Großer Komfort."],
        "Quit Monitor": ["Quit Monitor", "Monitor 종료", "Salir de Monitor", "退出 Monitor", "Monitor を終了", "Quitter Monitor", "Monitor beenden"],
        "Looking for your monitor…": ["Looking for your monitor…", "모니터를 찾고 있어요.", "Buscando tu monitor…", "正在查找显示器…", "モニターを検索中…", "Recherche de votre écran…", "Monitor wird gesucht…"],
        "One step at a time. Just right.": ["One step at a time. Just right.", "한 단계씩, 원하는 만큼만.", "Un paso cada vez. Justo a tu gusto.", "一步一步，恰到好处。", "一段階ずつ、ちょうどよく。", "Un palier à la fois. Juste comme il faut.", "Schritt für Schritt. Genau richtig."],
        "Checking your monitor…": ["Checking your monitor…", "모니터를 확인하고 있어요.", "Comprobando tu monitor…", "正在检查显示器…", "モニターを確認中…", "Vérification de votre écran…", "Monitor wird überprüft…"],
        "No DDC monitor found.": ["No DDC monitor found.", "연결된 DDC 모니터를 찾지 못했어요.", "No se encontró ningún monitor DDC.", "未找到 DDC 显示器。", "DDC モニターが見つかりません。", "Aucun écran DDC trouvé.", "Kein DDC-Monitor gefunden."],
        "Applying {0} {1}…": ["Applying {0} {1}…", "{0} {1} 적용 중…", "Aplicando {0} {1}…", "正在应用{0} {1}…", "{0} {1} を適用中…", "Application de {0} {1}…", "{0} {1} wird angewendet…"],
        "{0} {1} · Applied": ["{0} {1} · Applied", "{0} {1} · 적용 완료", "{0} {1} · Aplicado", "{0} {1} · 已应用", "{0} {1} · 適用済み", "{0} {1} · Appliqué", "{0} {1} · Angewendet"],
        "The monitor did not apply the requested value. Please check again.": ["The monitor did not apply the requested value. Please check again.", "모니터가 요청한 값을 적용하지 않았어요. 다시 확인해 주세요.", "El monitor no aplicó el valor solicitado. Compruébalo de nuevo.", "显示器未应用请求的值。请再次检查。", "モニターが指定の値を適用しませんでした。再確認してください。", "L’écran n’a pas appliqué la valeur demandée. Vérifiez à nouveau.", "Der Monitor hat den angeforderten Wert nicht übernommen. Bitte erneut prüfen."],
        "No response from the monitor. Please scan again.": ["No response from the monitor. Please scan again.", "모니터 응답을 확인할 수 없어요. 다시 검색해 주세요.", "El monitor no responde. Busca de nuevo.", "显示器无响应。请重新搜索。", "モニターから応答がありません。再検索してください。", "Aucune réponse de l’écran. Relancez la recherche.", "Keine Antwort vom Monitor. Bitte erneut suchen."],
        "Allow Monitor in System Settings → General → Login Items.": ["Allow Monitor in System Settings → General → Login Items.", "시스템 설정 → 일반 → 로그인 항목에서 Monitor를 허용해 주세요.", "Permite Monitor en Ajustes del Sistema → General → Ítems de inicio.", "请在系统设置 → 通用 → 登录项中允许 Monitor。", "システム設定 → 一般 → ログイン項目で Monitor を許可してください。", "Autorisez Monitor dans Réglages Système → Général → Ouverture.", "Erlaube Monitor unter Systemeinstellungen → Allgemein → Anmeldeobjekte."],
        "Could not change the login item: {0}": ["Could not change the login item: {0}", "로그인 항목을 변경하지 못했어요: {0}", "No se pudo cambiar el ítem de inicio: {0}", "无法更改登录项：{0}", "ログイン項目を変更できませんでした：{0}", "Impossible de modifier l’élément d’ouverture : {0}", "Anmeldeobjekt konnte nicht geändert werden: {0}"],
        "Monitor · Volume and brightness": ["Monitor · Volume and brightness", "Monitor · 볼륨과 밝기", "Monitor · Volumen y brillo", "Monitor · 音量与亮度", "Monitor · 音量と明るさ", "Monitor · Volume et luminosité", "Monitor · Lautstärke und Helligkeit"],
    ]
}
