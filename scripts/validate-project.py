#!/usr/bin/env python3
"""Perform dependency-free structural checks before generating the Xcode project."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "project.yml",
    ".github/workflows/build-unsigned-ipa.yml",
    "README.md",
    ".gitignore",
    "FocusFlow/App/AppContainer.swift",
    "FocusFlow/App/FocusFlowApp.swift",
    "FocusFlow/App/FocusFlowAppDelegate.swift",
    "FocusFlow/Models/DomainModels.swift",
    "FocusFlow/Models/RepeatRule.swift",
    "FocusFlow/Persistence/AppStore.swift",
    "FocusFlow/Services/BackupService.swift",
    "FocusFlow/Services/FeedbackService.swift",
    "FocusFlow/Services/NotificationService.swift",
    "FocusFlow/Services/SpeechService.swift",
    "FocusFlow/Services/WhiteNoiseService.swift",
    "FocusFlow/Timer/TimerEngine.swift",
    "FocusFlow/ViewModels/FocusViewModel.swift",
    "FocusFlow/ViewModels/StatisticsViewModel.swift",
    "FocusFlow/ViewModels/TodayViewModel.swift",
    "FocusFlow/Views/RootTabView.swift",
    "FocusFlow/Views/Focus/FocusView.swift",
    "FocusFlow/Views/Statistics/StatisticsView.swift",
    "FocusFlow/Views/Settings/SettingsView.swift",
    "FocusFlow/Views/Shared/DesignSystem.swift",
    "FocusFlow/Views/Tasks/TaskEditorView.swift",
    "FocusFlow/Views/Today/TodayView.swift",
    "FocusFlow/Resources/Assets.xcassets/Contents.json",
    "FocusFlow/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "FocusFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
)

PROJECT_MARKERS = (
    "name: FocusFlow",
    'iOS: "16.0"',
    "type: application",
    "type: bundle.unit-test",
    "path: FocusFlow",
    "path: FocusFlowTests",
    "hostApplication: FocusFlow",
    "ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon",
    "GENERATE_INFOPLIST_FILE: YES",
    "schemes:",
)

WORKFLOW_MARKERS = (
    "brew install xcodegen",
    "xcodegen generate --spec project.yml",
    "xcrun simctl list devices available -j",
    "-destination \"platform=iOS Simulator,id=${SIMULATOR_UDID}\"",
    "CODE_SIGNING_ALLOWED=NO",
    "-sdk iphoneos",
    "Payload",
    "FocusFlow-unsigned.ipa",
    "actions/upload-artifact@v4",
)


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def require_markers(path: Path, markers: tuple[str, ...], failures: list[str]) -> None:
    if not path.is_file():
        return

    contents = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in contents:
            fail(f"{path.relative_to(ROOT)} is missing marker: {marker}", failures)


def validate_asset_catalog(failures: list[str]) -> None:
    json_paths = (
        ROOT / "FocusFlow/Resources/Assets.xcassets/Contents.json",
        ROOT / "FocusFlow/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    )

    parsed: dict[Path, object] = {}
    for path in json_paths:
        if not path.is_file():
            continue
        try:
            parsed[path] = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"{path.relative_to(ROOT)} contains invalid JSON: {error}", failures)

    app_icon_path = json_paths[1]
    app_icon = parsed.get(app_icon_path)
    if isinstance(app_icon, dict):
        images = app_icon.get("images", [])
        filenames = {
            image.get("filename")
            for image in images
            if isinstance(image, dict) and image.get("filename")
        }
        if "AppIcon-1024.png" not in filenames:
            fail("AppIcon Contents.json does not reference AppIcon-1024.png", failures)


def main() -> int:
    failures: list[str] = []

    for relative_path in REQUIRED_FILES:
        if not (ROOT / relative_path).is_file():
            fail(f"Missing required file: {relative_path}", failures)

    test_directory = ROOT / "FocusFlowTests"
    if not test_directory.is_dir():
        fail("Missing required directory: FocusFlowTests", failures)
    elif not any(test_directory.rglob("*.swift")):
        fail("FocusFlowTests must contain at least one Swift test file", failures)

    require_markers(ROOT / "project.yml", PROJECT_MARKERS, failures)
    require_markers(
        ROOT / ".github/workflows/build-unsigned-ipa.yml",
        WORKFLOW_MARKERS,
        failures,
    )
    validate_asset_catalog(failures)

    if failures:
        print("FocusFlow project validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    swift_count = sum(1 for _ in (ROOT / "FocusFlow").rglob("*.swift"))
    test_count = sum(1 for _ in test_directory.rglob("*.swift"))
    print(
        "FocusFlow project validation passed "
        f"({swift_count} app Swift files, {test_count} test Swift files)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
