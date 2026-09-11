#!/usr/bin/env python3
"""A cheap static pass over the iOS sources.

There is no Swift toolchain in this environment, so this cannot type-check
anything. What it can catch is the class of mistake that has actually bitten
this project before: a view referenced but never written, a type declared
twice, or a file whose braces do not close.

Usage:  python3 tools/check_ios_swift.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "ios", "IronLeague")

# only top level: a nested CodingKeys or Mode is legal in every type
DECL = re.compile(r"^(?:public |private |fileprivate |internal )?"
                  r"(?:final )?(struct|class|enum|protocol|actor) (\w+)", re.M)
MEMBER = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
                    r"(?:public|private|fileprivate|internal|static|final|lazy|weak|var|let|func)\b")

# Types that come from the SDKs rather than from this codebase.
KNOWN = {
    # Swift / Foundation
    "String", "Int", "Double", "Bool", "UUID", "Date", "Data", "URL", "Error",
    "Array", "Dictionary", "Set", "Optional", "Task", "Result", "Void",
    "Calendar", "TimeZone", "DateFormatter", "ISO8601DateFormatter", "Bundle",
    "UserDefaults", "Timer", "NSError", "CGFloat", "CGPoint", "CGRect",
    "CGSize", "UInt32", "UInt64", "Codable", "Decodable", "Encodable",
    "Hashable", "Identifiable", "Equatable", "Comparable", "CaseIterable",
    "Sendable", "RawRepresentable", "Animatable", "Observation", "Foundation",
    "Swift", "Character", "Substring", "AnyHashable", "Never", "Float",
    # SwiftUI
    "View", "App", "Scene", "WindowGroup", "Text", "Image", "Button", "VStack",
    "HStack", "ZStack", "LazyVStack", "LazyVGrid", "LazyHStack", "GridItem",
    "ScrollView", "ScrollViewReader", "List", "ForEach", "Spacer", "Divider",
    "Color", "Font", "Angle", "Path", "Shape", "InsettableShape", "Circle",
    "Capsule", "Rectangle", "RoundedRectangle", "Ellipse", "LinearGradient",
    "RadialGradient", "Gradient", "AnyShapeStyle", "ShapeStyle", "Canvas",
    "GraphicsContext", "TimelineView", "GeometryReader", "Namespace",
    "NavigationStack", "NavigationLink", "Toggle", "Slider", "TextField",
    "SecureField", "Menu", "Label", "ShareLink", "Section", "Group",
    "ToolbarItem", "ToolbarItemGroup", "Binding", "State", "StateObject",
    "Environment", "EnvironmentObject", "FocusState", "ViewBuilder",
    "ButtonStyle", "PrimitiveButtonStyle", "Animation", "Transition",
    "AnyTransition", "UnitPoint", "Alignment", "Edge", "StrokeStyle",
    "ContentMode", "KeyPath", "PreviewProvider", "UIPasteboard",
    "UIImpactFeedbackGenerator", "UINotificationFeedbackGenerator",
    "UIApplication", "SwiftUI", "UIKit", "EdgeInsets", "Text.Case",
    # Supabase
    "Supabase", "SupabaseClient", "AnyJSON", "PostgrestClient", "FetchOptions",
    # language and generic placeholders
    "CodingKey", "CodingKeys", "Decoder", "Encoder", "Self", "Type",
    "MainActor", "Observable", "Configuration", "Content", "Item", "Element",
    "Value", "Output", "Failure",
}


def main():
    files = []
    for base, _, names in os.walk(ROOT):
        for n in names:
            if n.endswith(".swift"):
                files.append(os.path.join(base, n))
    files.sort()

    declared = {}
    problems = []

    for path in files:
        src = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, ROOT)

        # braces, ignoring anything inside a string or a comment
        stripped = strip_noise(src)
        for open_ch, close_ch, what in (("{", "}", "braces"),
                                        ("(", ")", "parens"),
                                        ("[", "]", "brackets")):
            if stripped.count(open_ch) != stripped.count(close_ch):
                problems.append("%s: unbalanced %s (%d vs %d)"
                                % (rel, what, stripped.count(open_ch),
                                   stripped.count(close_ch)))

        for kind, name in DECL.findall(src):
            if name in declared:
                problems.append("%s: %s %s already declared in %s"
                                % (rel, kind, name, declared[name]))
            else:
                declared[name] = rel

    # nested types are legal anywhere, so they count as declared for the
    # "does this name exist" pass even though they are not top level
    nested = set()
    for path in files:
        src = open(path, encoding="utf-8").read()
        nested |= set(re.findall(
            r"^\s+(?:public |private |fileprivate |internal )?"
            r"(?:final |indirect )?(?:struct|class|enum|protocol|actor) (\w+)",
            src, re.M))

    known = set(KNOWN) | set(declared) | nested
    used = {}
    for path in files:
        src = strip_noise(open(path, encoding="utf-8").read())
        rel = os.path.relpath(path, ROOT)
        for name in set(re.findall(r"\b([A-Z][A-Za-z0-9]{2,})\b", src)):
            used.setdefault(name, set()).add(rel)

    unknown = sorted(n for n in used if n not in known)
    # nested types (Skin.Well, League.Badge…) and enum cases read as unknown,
    # so only report names that are never a member of something declared here
    member_of = set()
    for path in files:
        src = open(path, encoding="utf-8").read()
        for outer, inner in re.findall(r"\b([A-Z][A-Za-z0-9]*)\.([A-Z][A-Za-z0-9]*)", src):
            if outer in declared or outer in KNOWN:
                member_of.add(inner)
    unknown = [n for n in unknown if n not in member_of]

    print("files      : %d" % len(files))
    print("types      : %d" % len(declared))
    if unknown:
        print("\nNAMES USED BUT NOT DECLARED HERE OR KNOWN TO THIS CHECK")
        for n in unknown:
            print("  · %-28s %s" % (n, ", ".join(sorted(used[n]))))
    if problems:
        print("\nPROBLEMS")
        for p in problems:
            print("  · %s" % p)
        sys.exit(1)
    if not unknown:
        print("no unbalanced files, no duplicate types, no unknown names")


def strip_noise(src):
    src = re.sub(r'"""(?:.|\n)*?"""', '""', src)
    src = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', src)
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r"/\*(?:.|\n)*?\*/", "", src)
    return src


if __name__ == "__main__":
    main()
