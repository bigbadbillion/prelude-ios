#!/usr/bin/env python3
"""Generate Prelude.xcodeproj from Swift sources under Prelude/Prelude/ and PreludeTests/."""
from __future__ import annotations

import uuid
from pathlib import Path


def gid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    src = root / "Prelude"
    out = root / "Prelude.xcodeproj" / "project.pbxproj"
    swift_files = sorted(src.rglob("*.swift"), key=lambda p: str(p))
    assert swift_files, f"No Swift under {src}"

    tests_dir = root / "PreludeTests"
    test_swift_files = sorted(tests_dir.rglob("*.swift"), key=lambda p: str(p)) if tests_dir.is_dir() else []
    has_tests = bool(test_swift_files)

    file_refs = {gid(): f for f in swift_files}
    asset_ref, privacy_ref, product_ref = gid(), gid(), gid()
    main_group, prelude_group, products_group = gid(), gid(), gid()
    project_obj, target = gid(), gid()
    sources_phase, resources_phase = gid(), gid()
    config_list_project, config_list_target = gid(), gid()
    debug_p, rel_p, debug_t, rel_t = gid(), gid(), gid(), gid()
    build_asset, build_privacy = gid(), gid()

    if has_tests:
        test_file_refs = {gid(): f for f in test_swift_files}
        test_product_ref = gid()
        tests_group = gid()
        test_target = gid()
        test_sources_phase = gid()
        test_config_list_target = gid()
        test_debug_t, test_rel_t = gid(), gid()
        container_proxy = gid()
        target_dep = gid()
        test_bfs = {gid(): fr for fr in test_file_refs}
    else:
        test_file_refs = {}
        test_bfs = {}

    fr_ids = list(file_refs.keys())
    bfs = {gid(): fr for fr in fr_ids}

    lines: list[str] = []

    def a(x: str = "") -> None:
        lines.append(x)

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")

    for bf, fr in bfs.items():
        name = file_refs[fr].name
        a(f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};")
    if has_tests:
        for bf, fr in test_bfs.items():
            name = test_file_refs[fr].name
            a(f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};")
    a(f"\t\t{build_asset} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {asset_ref} /* Assets.xcassets */; }};")
    a(f"\t\t{build_privacy} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_ref} /* PrivacyInfo.xcprivacy */; }};")
    a("")

    for fr, p in file_refs.items():
        rel = p.relative_to(root).as_posix()
        a(f"\t\t{fr} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{rel}\"; sourceTree = \"<group>\"; }};")
    if has_tests:
        for fr, p in test_file_refs.items():
            rel = p.relative_to(root).as_posix()
            a(f"\t\t{fr} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{rel}\"; sourceTree = \"<group>\"; }};")
        a(f"\t\t{test_product_ref} /* PreludeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PreludeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{asset_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Prelude/Assets.xcassets; sourceTree = \"<group>\"; }};")
    a(f"\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = Prelude/PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};")
    a(f"\t\t{product_ref} /* Prelude.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Prelude.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a("")

    prelude_children = ", ".join([*fr_ids, asset_ref, privacy_ref])
    a("\t\t/* Begin PBXGroup section */")
    a(f"\t\t{prelude_group} = {{")
    a("\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = ({prelude_children});")
    a("\t\t\tname = Prelude;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")
    if has_tests:
        test_fr_ids = list(test_file_refs.keys())
        test_ch = ", ".join(test_fr_ids)
        a(f"\t\t{tests_group} = {{")
        a("\t\t\tisa = PBXGroup;")
        a(f"\t\t\tchildren = ({test_ch});")
        a("\t\t\tname = PreludeTests;")
        a("\t\t\tsourceTree = \"<group>\";")
        a("\t\t};")
    prod_ch = f"{product_ref}, {test_product_ref}" if has_tests else product_ref
    a(f"\t\t{products_group} = {{")
    a("\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = ({prod_ch});")
    a("\t\t\tname = Products;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")
    mg_ch = f"{prelude_group}, {tests_group}, {products_group}" if has_tests else f"{prelude_group}, {products_group}"
    a(f"\t\t{main_group} = {{")
    a("\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = ({mg_ch});")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")
    a("\t\t/* End PBXGroup section */")
    a("")

    a("\t\t/* Begin PBXNativeTarget section */")
    a(f"\t\t{target} /* Prelude */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {config_list_target};")
    a(f"\t\t\tbuildPhases = ({sources_phase}, {resources_phase});")
    a("\t\t\tbuildRules = ();")
    a("\t\t\tdependencies = ();")
    a("\t\t\tname = Prelude;")
    a("\t\t\tproductName = Prelude;")
    a(f"\t\t\tproductReference = {product_ref} /* Prelude.app */;")
    a("\t\t\tproductType = \"com.apple.product-type.application\";")
    a("\t\t};")
    if has_tests:
        a(f"\t\t{test_target} /* PreludeTests */ = {{")
        a("\t\t\tisa = PBXNativeTarget;")
        a(f"\t\t\tbuildConfigurationList = {test_config_list_target};")
        a(f"\t\t\tbuildPhases = ({test_sources_phase});")
        a("\t\t\tbuildRules = ();")
        a(f"\t\t\tdependencies = ({target_dep} /* PBXTargetDependency */);")
        a("\t\t\tname = PreludeTests;")
        a("\t\t\tproductName = PreludeTests;")
        a(f"\t\t\tproductReference = {test_product_ref} /* PreludeTests.xctest */;")
        a("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
        a("\t\t};")
    a("\t\t/* End PBXNativeTarget section */")
    a("")

    if has_tests:
        a("\t\t/* Begin PBXContainerItemProxy section */")
        a(f"\t\t{container_proxy} /* PBXContainerItemProxy */ = {{")
        a("\t\t\tisa = PBXContainerItemProxy;")
        a(f"\t\t\tcontainerPortal = {project_obj} /* Project object */;")
        a("\t\t\tproxyType = 1;")
        a(f"\t\t\tremoteGlobalIDString = {target};")
        a("\t\t\tremoteInfo = Prelude;")
        a("\t\t};")
        a("\t\t/* End PBXContainerItemProxy section */")
        a("")
        a("\t\t/* Begin PBXTargetDependency section */")
        a(f"\t\t{target_dep} /* PBXTargetDependency */ = {{")
        a("\t\t\tisa = PBXTargetDependency;")
        a(f"\t\t\ttarget = {target} /* Prelude */;")
        a(f"\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;")
        a("\t\t};")
        a("\t\t/* End PBXTargetDependency section */")
        a("")

    tgt_list = f"{target} /* Prelude */, {test_target} /* PreludeTests */" if has_tests else f"{target} /* Prelude */"
    a("\t\t/* Begin PBXProject section */")
    a(f"\t\t{project_obj} /* Project object */ = {{")
    a("\t\t\tisa = PBXProject;")
    a("\t\t\tattributes = {LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500; BuildIndependentTargetsInParallel = 1; };")
    a(f"\t\t\tbuildConfigurationList = {config_list_project};")
    a("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a("\t\t\tdevelopmentRegion = en;")
    a("\t\t\thasScannedForEncodings = 0;")
    a("\t\t\tknownRegions = (en, Base);")
    a(f"\t\t\tmainGroup = {main_group};")
    a(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    a(f"\t\t\ttargets = ({tgt_list});")
    a("\t\t};")
    a("\t\t/* End PBXProject section */")
    a("")

    bf_list = ", ".join(bfs.keys())
    a("\t\t/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{sources_phase} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = ({bf_list});")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    if has_tests:
        tbf_list = ", ".join(test_bfs.keys())
        a(f"\t\t{test_sources_phase} /* Sources */ = {{")
        a("\t\t\tisa = PBXSourcesBuildPhase;")
        a("\t\t\tbuildActionMask = 2147483647;")
        a(f"\t\t\tfiles = ({tbf_list});")
        a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        a("\t\t};")
    a("\t\t/* End PBXSourcesBuildPhase section */")
    a("")

    a("\t\t/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{resources_phase} /* Resources */ = {{")
    a("\t\t\tisa = PBXResourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = ({build_asset}, {build_privacy});")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("\t\t/* End PBXResourcesBuildPhase section */")
    a("")

    a("\t\t/* Begin XCBuildConfiguration section */")
    for cfg_id, name, is_target in [
        (debug_p, "Debug", False),
        (rel_p, "Release", False),
        (debug_t, "Debug", True),
        (rel_t, "Release", True),
    ]:
        a(f"\t\t{cfg_id} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        if is_target:
            a("\t\t\tbuildSettings = {")
            a("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
            a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
            a("\t\t\t\tSDKROOT = iphoneos;")
            a("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
            a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
            a("\t\t\t\tDEVELOPMENT_TEAM = 439GU2NXZH;")
            a("\t\t\t\tENABLE_PREVIEWS = YES;")
            if name == "Debug":
                a("\t\t\t\tENABLE_TESTABILITY = YES;")
            a("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
            a("\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = \"Prelude uses the microphone for your reflection session.\";")
            a("\t\t\t\tINFOPLIST_KEY_NSSpeechRecognitionUsageDescription = \"Prelude transcribes your speech on device during sessions.\";")
            a("\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
            a("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;")
            a("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\");")
            a("\t\t\t\tMARKETING_VERSION = 1.0;")
            a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.prelude.Prelude;")
            a("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            a("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
            a("\t\t\t\tSWIFT_VERSION = 5.0;")
            a("\t\t\t\tTARGETED_DEVICE_FAMILY = 1;")
            a("\t\t\t};")
        else:
            a("\t\t\tbuildSettings = {")
            a("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
            a("\t\t\t\tSWIFT_VERSION = 5.0;")
            a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    if has_tests:
        for cfg_id, name in [(test_debug_t, "Debug"), (test_rel_t, "Release")]:
            a(f"\t\t{cfg_id} /* {name} */ = {{")
            a("\t\t\tisa = XCBuildConfiguration;")
            a("\t\t\tbuildSettings = {")
            a("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
            a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
            a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
            a("\t\t\t\tDEVELOPMENT_TEAM = 439GU2NXZH;")
            a("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
            a("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;")
            a("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\", \"@loader_path/Frameworks\");")
            a("\t\t\t\tMARKETING_VERSION = 1.0;")
            a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.prelude.PreludeTests;")
            a("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            a("\t\t\t\tSDKROOT = iphoneos;")
            a("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
            a("\t\t\t\tSWIFT_VERSION = 5.0;")
            a("\t\t\t\tTARGETED_DEVICE_FAMILY = 1;")
            a("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Prelude.app/Prelude\";")
            a("\t\t\t};")
            a(f"\t\t\tname = {name};")
            a("\t\t};")

    a("\t\t/* End XCBuildConfiguration section */")
    a("")

    a("\t\t/* Begin XCConfigurationList section */")
    a(f"\t\t{config_list_project} /* Build configuration list for PBXProject */ = {{")
    a("\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = ({debug_p} /* Debug */, {rel_p} /* Release */);")
    a("\t\t\tdefaultConfigurationIsVisible = 0;")
    a("\t\t\tdefaultConfigurationName = Release;")
    a("\t\t};")
    a(f"\t\t{config_list_target} /* Build configuration list for PBXNativeTarget \"Prelude\" */ = {{")
    a("\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = ({debug_t} /* Debug */, {rel_t} /* Release */);")
    a("\t\t\tdefaultConfigurationIsVisible = 0;")
    a("\t\t\tdefaultConfigurationName = Release;")
    a("\t\t};")
    if has_tests:
        a(f"\t\t{test_config_list_target} /* Build configuration list for PBXNativeTarget \"PreludeTests\" */ = {{")
        a("\t\t\tisa = XCConfigurationList;")
        a(f"\t\t\tbuildConfigurations = ({test_debug_t} /* Debug */, {test_rel_t} /* Release */);")
        a("\t\t\tdefaultConfigurationIsVisible = 0;")
        a("\t\t\tdefaultConfigurationName = Release;")
        a("\t\t};")
    a("\t\t/* End XCConfigurationList section */")

    a("\t};")
    a(f"\trootObject = {project_obj} /* Project object */;")
    a("}")

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
