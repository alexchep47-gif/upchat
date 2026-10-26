#!/usr/bin/env python3
"""Add an injected GoogleService-Info.plist to the generated Runner Xcode project."""
from pathlib import Path
import re
import sys

project = Path(sys.argv[1] if len(sys.argv) > 1 else 'ios/Runner.xcodeproj/project.pbxproj')
plist = Path(sys.argv[2] if len(sys.argv) > 2 else 'ios/Runner/GoogleService-Info.plist')
if not project.exists() or not plist.exists():
    raise SystemExit('iOS project or Firebase plist is missing')
text = project.read_text()
if 'GoogleService-Info.plist in Resources' in text:
    raise SystemExit(0)
file_ref = 'FBA1234567890ABCDEF1234'
build_ref = 'FBB1234567890ABCDEF1234'
text = text.replace(
    '/* Begin PBXBuildFile section */',
    '/* Begin PBXBuildFile section */\n\t\t%s /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = %s /* GoogleService-Info.plist */; };' % (build_ref, file_ref),
    1,
)
text = text.replace(
    '/* Begin PBXFileReference section */',
    '/* Begin PBXFileReference section */\n\t\t%s /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };' % file_ref,
    1,
)
# Put the reference in the Runner group so Xcode shows it and it is copied by Resources.
runner_group = re.search(r'(\/\* Runner \/\* = \{\n.*?children = \(\n)(.*?)(\n\s*\);)', text, re.S)
if runner_group:
    block = runner_group.group(0)
    block = block.replace('children = (\n', 'children = (\n\t\t\t\t%s /* GoogleService-Info.plist */,\n' % file_ref, 1)
    text = text.replace(runner_group.group(0), block, 1)
# Add the build file to the first resources phase.
resources = re.search(r'(\/\* Resources \*\/ = \{\n.*?files = \(\n)(.*?)(\n\s*\);)', text, re.S)
if not resources:
    raise SystemExit('PBXResourcesBuildPhase not found')
block = resources.group(0)
block = block.replace('files = (\n', 'files = (\n\t\t\t\t%s /* GoogleService-Info.plist in Resources */,\n' % build_ref, 1)
text = text.replace(resources.group(0), block, 1)
project.write_text(text)
