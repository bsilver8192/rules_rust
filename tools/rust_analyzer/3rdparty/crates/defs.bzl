###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @//tools/rust_analyzer/3rdparty:crates_vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependnecies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({_CONDITIONS[condition]: deps.values()})

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": common_items}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        if condition_triples in crate_aliases:
            crate_aliases[condition_triples].update(deps)
        else:
            crate_aliases.update({_CONDITIONS[condition]: dict(deps.items() + common_items)})

    return selects.with_or(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "": {
        _COMMON_CONDITION: {
            "anyhow": "@rules_rust_rust_analyzer__anyhow-1.0.68//:anyhow",
            "clap": "@rules_rust_rust_analyzer__clap-3.2.23//:clap",
            "env_logger": "@rules_rust_rust_analyzer__env_logger-0.9.3//:env_logger",
            "itertools": "@rules_rust_rust_analyzer__itertools-0.10.5//:itertools",
            "log": "@rules_rust_rust_analyzer__log-0.4.17//:log",
            "serde": "@rules_rust_rust_analyzer__serde-1.0.152//:serde",
            "serde_json": "@rules_rust_rust_analyzer__serde_json-1.0.91//:serde_json",
        },
    },
}

_NORMAL_ALIASES = {
    "": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "": {
    },
}

_NORMAL_DEV_ALIASES = {
    "": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_ALIASES = {
    "": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "": {
    },
}

_BUILD_DEPENDENCIES = {
    "": {
    },
}

_BUILD_ALIASES = {
    "": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "": {
    },
}

_CONDITIONS = {
    "cfg(target_os = \"hermit\")": [],
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(windows)": ["aarch64-pc-windows-msvc", "i686-pc-windows-msvc", "x86_64-pc-windows-msvc"],
    "i686-pc-windows-gnu": [],
    "x86_64-pc-windows-gnu": [],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__aho-corasick-0.7.20",
        sha256 = "cc936419f96fa211c1b9166887b38e5e40b19958e5b895be7c1f93adec7071ac",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/aho-corasick/0.7.20/download"],
        strip_prefix = "aho-corasick-0.7.20",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.aho-corasick-0.7.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__anyhow-1.0.68",
        sha256 = "2cb2f989d18dd141ab8ae82f64d1a8cdd37e0840f73a406896cf5e99502fab61",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/anyhow/1.0.68/download"],
        strip_prefix = "anyhow-1.0.68",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.anyhow-1.0.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__atty-0.2.14",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/atty/0.2.14/download"],
        strip_prefix = "atty-0.2.14",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__autocfg-1.1.0",
        sha256 = "d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/autocfg/1.1.0/download"],
        strip_prefix = "autocfg-1.1.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.autocfg-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__clap-3.2.23",
        sha256 = "71655c45cb9845d3270c9d6df84ebe72b4dad3c2ba3f7023ad47c144e4e473a5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap/3.2.23/download"],
        strip_prefix = "clap-3.2.23",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.clap-3.2.23.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__clap_derive-3.2.18",
        sha256 = "ea0c8bce528c4be4da13ea6fead8965e95b6073585a2f05204bd8f4119f82a65",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_derive/3.2.18/download"],
        strip_prefix = "clap_derive-3.2.18",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.clap_derive-3.2.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__clap_lex-0.2.4",
        sha256 = "2850f2f5a82cbf437dd5af4d49848fbdfc27c157c3d010345776f952765261c5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_lex/0.2.4/download"],
        strip_prefix = "clap_lex-0.2.4",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.clap_lex-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__either-1.8.0",
        sha256 = "90e5c1c8368803113bf0c9584fc495a58b86dc8a29edbf8fe877d21d9507e797",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/either/1.8.0/download"],
        strip_prefix = "either-1.8.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.either-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__env_logger-0.9.3",
        sha256 = "a12e6657c4c97ebab115a42dcee77225f7f482cdd841cf7088c657a42e9e00e7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/env_logger/0.9.3/download"],
        strip_prefix = "env_logger-0.9.3",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.env_logger-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__hashbrown-0.12.3",
        sha256 = "8a9ee70c43aaf417c914396645a0fa852624801b24ebb7ae78fe8272889ac888",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hashbrown/0.12.3/download"],
        strip_prefix = "hashbrown-0.12.3",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.hashbrown-0.12.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__heck-0.4.0",
        sha256 = "2540771e65fc8cb83cd6e8a237f70c319bd5c29f78ed1084ba5d50eeac86f7f9",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/heck/0.4.0/download"],
        strip_prefix = "heck-0.4.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.heck-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__humantime-2.1.0",
        sha256 = "9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/humantime/2.1.0/download"],
        strip_prefix = "humantime-2.1.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.humantime-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__indexmap-1.9.2",
        sha256 = "1885e79c1fc4b10f0e172c475f458b7f7b93061064d98c3293e98c5ba0c8b399",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/indexmap/1.9.2/download"],
        strip_prefix = "indexmap-1.9.2",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.indexmap-1.9.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__itertools-0.10.5",
        sha256 = "b0fd2260e829bddf4cb6ea802289de2f86d6a7a690192fbe91b3f46e0f2c8473",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/itertools/0.10.5/download"],
        strip_prefix = "itertools-0.10.5",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.itertools-0.10.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__itoa-1.0.5",
        sha256 = "fad582f4b9e86b6caa621cabeb0963332d92eea04729ab12892c2533951e6440",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/itoa/1.0.5/download"],
        strip_prefix = "itoa-1.0.5",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.itoa-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__libc-0.2.139",
        sha256 = "201de327520df007757c1f0adce6e827fe8562fbc28bfd9c15571c66ca1f5f79",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.139/download"],
        strip_prefix = "libc-0.2.139",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.libc-0.2.139.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__log-0.4.17",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/log/0.4.17/download"],
        strip_prefix = "log-0.4.17",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__memchr-2.5.0",
        sha256 = "2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/memchr/2.5.0/download"],
        strip_prefix = "memchr-2.5.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.memchr-2.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__once_cell-1.17.0",
        sha256 = "6f61fba1741ea2b3d6a1e3178721804bb716a68a6aeba1149b5d52e3d464ea66",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/once_cell/1.17.0/download"],
        strip_prefix = "once_cell-1.17.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.once_cell-1.17.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__os_str_bytes-6.4.1",
        sha256 = "9b7820b9daea5457c9f21c69448905d723fbd21136ccf521748f23fd49e723ee",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/os_str_bytes/6.4.1/download"],
        strip_prefix = "os_str_bytes-6.4.1",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.os_str_bytes-6.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__proc-macro-error-1.0.4",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download"],
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__proc-macro-error-attr-1.0.4",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download"],
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__proc-macro2-1.0.49",
        sha256 = "57a8eca9f9c4ffde41714334dee777596264c7825420f521abc92b5b5deb63a5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro2/1.0.49/download"],
        strip_prefix = "proc-macro2-1.0.49",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.proc-macro2-1.0.49.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__quote-1.0.23",
        sha256 = "8856d8364d252a14d474036ea1358d63c9e6965c8e5c1885c18f73d70bff9c7b",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/quote/1.0.23/download"],
        strip_prefix = "quote-1.0.23",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.quote-1.0.23.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__regex-1.7.0",
        sha256 = "e076559ef8e241f2ae3479e36f97bd5741c0330689e217ad51ce2c76808b868a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex/1.7.0/download"],
        strip_prefix = "regex-1.7.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.regex-1.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__regex-syntax-0.6.28",
        sha256 = "456c603be3e8d448b072f410900c09faf164fbce2d480456f50eea6e25f9c848",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex-syntax/0.6.28/download"],
        strip_prefix = "regex-syntax-0.6.28",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.regex-syntax-0.6.28.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__ryu-1.0.12",
        sha256 = "7b4b9743ed687d4b4bcedf9ff5eaa7398495ae14e61cba0a295704edbc7decde",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/ryu/1.0.12/download"],
        strip_prefix = "ryu-1.0.12",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.ryu-1.0.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__serde-1.0.152",
        sha256 = "bb7d1f0d3021d347a83e556fc4683dea2ea09d87bccdf88ff5c12545d89d5efb",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/serde/1.0.152/download"],
        strip_prefix = "serde-1.0.152",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.serde-1.0.152.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__serde_derive-1.0.152",
        sha256 = "af487d118eecd09402d70a5d72551860e788df87b464af30e5ea6a38c75c541e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/serde_derive/1.0.152/download"],
        strip_prefix = "serde_derive-1.0.152",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.serde_derive-1.0.152.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__serde_json-1.0.91",
        sha256 = "877c235533714907a8c2464236f5c4b2a17262ef1bd71f38f35ea592c8da6883",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/serde_json/1.0.91/download"],
        strip_prefix = "serde_json-1.0.91",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.serde_json-1.0.91.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__strsim-0.10.0",
        sha256 = "73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/strsim/0.10.0/download"],
        strip_prefix = "strsim-0.10.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.strsim-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__syn-1.0.107",
        sha256 = "1f4064b5b16e03ae50984a5a8ed5d4f8803e6bc1fd170a3cda91a1be4b18e3f5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/syn/1.0.107/download"],
        strip_prefix = "syn-1.0.107",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.syn-1.0.107.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__termcolor-1.1.3",
        sha256 = "bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/termcolor/1.1.3/download"],
        strip_prefix = "termcolor-1.1.3",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.termcolor-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__textwrap-0.16.0",
        sha256 = "222a222a5bfe1bba4a77b45ec488a741b3cb8872e5e499451fd7d0129c9c7c3d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/textwrap/0.16.0/download"],
        strip_prefix = "textwrap-0.16.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.textwrap-0.16.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__unicode-ident-1.0.6",
        sha256 = "84a22b9f218b40614adcb3f4ff08b703773ad44fa9423e4e0d346d5db86e4ebc",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-ident/1.0.6/download"],
        strip_prefix = "unicode-ident-1.0.6",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.unicode-ident-1.0.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__version_check-0.9.4",
        sha256 = "49874b5167b65d7193b8aba1567f5c7d93d001cafc34600cee003eda787e483f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/version_check/0.9.4/download"],
        strip_prefix = "version_check-0.9.4",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.version_check-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__winapi-util-0.1.5",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-util/0.1.5/download"],
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_rust_analyzer__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@rules_rust//tools/rust_analyzer/3rdparty/crates:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
