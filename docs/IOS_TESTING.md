# Проверка iOS на Mac

## Статус

iOS target поддерживается архитектурно с первого Sprint, но Xcode toolchain недоступен на Windows. Невозможность локально собрать iOS на Windows ожидаема и не является ошибкой Flutter-проекта. Этот документ описывает будущую проверку на Mac и не утверждает, что iOS build уже выполнен.

## 1. Подготовить Mac

Установить:

- Flutter `3.44.7` stable и входящий в него Dart SDK;
- актуальный совместимый Xcode из App Store/Apple Developer;
- Xcode Command Line Tools;
- CocoaPods, если он требуется используемыми Flutter plugins;
- Git либо иной способ получить рабочую копию проекта.

Проверить:

```bash
flutter --version
dart --version
xcodebuild -version
flutter doctor -v
flutter devices
```

Принять лицензию Xcode и запустить Xcode хотя бы один раз, если этого требует установка:

```bash
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

Не следует устанавливать CocoaPods, если текущий набор plugins его не требует. При необходимости используйте поддерживаемый для Mac способ установки и проверьте `pod --version`.

## 2. Получить зависимости

Из корня проекта:

```bash
flutter clean
flutter pub get
flutter precache --ios
```

Если Flutter сообщает о необходимости pods:

```bash
cd ios
pod install --repo-update
cd ..
```

Всегда открывайте workspace, когда он создан CocoaPods:

```bash
open ios/Runner.xcworkspace
```

Без CocoaPods можно открыть `ios/Runner.xcodeproj`, но workspace безопаснее для plugin-проекта.

## 3. Настроить Runner и signing

В Xcode выбрать target `Runner` и проверить:

- уникальный Bundle Identifier для организации;
- Apple Developer Team;
- Automatically manage signing либо утверждённые provisioning profiles;
- iOS Deployment Target, совместимый с Flutter и всеми plugins;
- одинаковые bundle settings для Debug/Profile/Release;
- отсутствие случайно закоммиченных certificates, profiles и secret values.

Для Simulator signing обычно не нужен. Для физического iPhone устройство и Apple ID/Team должны быть доверены и доступны Xcode.

## 4. Статические проверки и tests

Из корня проекта выполнить:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Затем проверить доступные targets:

```bash
flutter devices
```

## 5. Запуск

Запустить Simulator из Xcode либо командой `open -a Simulator`, затем:

```bash
flutter run -d <ios-device-id>
```

Для физического устройства выбрать его id и убедиться, что signing завершён:

```bash
flutter run -d <iphone-device-id>
```

Дополнительная compile-проверка без подписи:

```bash
flutter build ios --debug --no-codesign
```

Успешный Android build не заменяет эту проверку.

## 6. Ручной smoke test

На Simulator и хотя бы одном физическом iPhone проверить:

1. Первый запуск и состояние «Quran content не загружен».
2. Светлую/тёмную тему и системное переключение.
3. Добавление и активность выученной пользовательской записи.
4. Выбор Фаджра/Асра/Нафля и режима каза для обязательного намаза.
5. Регистрацию чтения, Snackbar и Undo.
6. Перезапуск приложения с сохранением состояния.
7. Историю, подтверждение удаления и корректный rebuild.
8. Статистику по типу намаза.
9. Этапы обучения, `Повторил`, `Выучил` и карточку на главной.
10. Полностью offline-регистрацию после отключения сети.
11. Русские строки, длинные aliases, Dynamic Type и отсутствие clipping.
12. RTL rendering только для проверенного арабского content; перевод остаётся LTR.
13. Отсутствие Android-only путей, разрешений и assumptions в общем коде.

Для проверки 72 часов использовать инъецируемый test clock в tests, а не менять системные часы устройства.

## 7. Release readiness

До TestFlight дополнительно нужны:

- постоянные Bundle ID, display name и version/build number;
- App Store Connect application record;
- distribution signing и capabilities;
- privacy manifest/описания использования данных и разрешений;
- app icons, launch assets и metadata;
- release build и archive через Xcode или Flutter;
- тест на поддерживаемых версиях iOS;
- отсутствие secrets и отладочных endpoints в archive.

Пример создания release build после настройки подписи:

```bash
flutter build ipa --release
```

Archive загружается в App Store Connect штатными инструментами Xcode/Transporter, затем назначается внутренней группе TestFlight. Конкретные результаты signing, build и TestFlight фиксируются только после фактического выполнения на Mac.
