load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("@rules_ocaml//build:rules.bzl",
     "ocaml_binary",
     "ocaml_library",
     "ocaml_ns",
     "ocaml_module",
     "ocaml_signature")

load("ctypes_genrule.bzl",
     "ctypes_types_gen", "ctypes_functions_gen")

OPTS = ["-w", "@1..3@5..28@31..39@43@46..47@49..57@61..62@67@69-40"]
DEPS = []

def _ctypes_module_impl(name,
                      api_name,
                      visibility,
                      functors,
                      types_module,
                      wrapper,
                      cclibs,
                      cchdrs,
                      **kwargs):

    mname = name[:1].capitalize() + name[1:]

    if api_name == "":
        api_name = name + "_api"
    #     ns_name = name
    # else:
    # ns_name = api_name

    # dune compatibility: ep ends up as a submodule
    # in the API module (e.g. Zstd_stubs.C)
    # dune generates a file for the ep, e.g. c.ml
    # but this is unnecessary since namespacing
    # renames it anyway (to Zstd_stubs__C).
    # and all c.ml does is alias Types and Functions
    # so instead, we embed those aliases directly
    # in the API module (Zstd_stubs), within
    # module <ep> struct ... end
    if wrapper == "":
        ep      = False
    else:
        ep       = True
        ep_mname = wrapper[:1].capitalize() + wrapper[1:]

    # api_name  = ns_name # + "_stubs" # ns_name + ".ml.gen"
    ep_ml    = api_name + ".ml"

    if types_module == "":
        types_module_name = mname + "_Types"
    else:
        types_module_name = types_module

    items    = functors.items()
    tfunctor = items[0][1]
    tmodfile  = items[0][0]
    tmodbase  = tmodfile.name
    (stem, ext) = paths.split_extension(tmodbase)
    tmod = stem[:1].capitalize() + stem[1:]

    fnfunctor = items[1][1]
    fmodfile  = items[1][0]
    fmodbase  = fmodfile.name
    (stem, ext) = paths.split_extension(fmodbase)
    fmod = stem[:1].capitalize() + stem[1:]

    functions_wrapper_mod = name + "FunctionsWrapper"

    hdrlines = []

    ################
    ## final step: generate module_name module
    ## for dune this is an ns resolver exposing the wrapper
    ## and a bunch of other modules.
    ## I don’t see the point of that, those are implementation
    ## details. e.g.
    ## module Libzstd__type_gen = Zstd_stubs__Libzstd__type_gen
    ## is only used as a build tool. so we don’t do that

    # if ep:
    #     ocaml_module(
    #         name   = module_name,
    #         # module_name = module_name,
    #         struct = ns_name + ".ml",
    #         opts   = OPTS,
    #         deps   = DEPS + [
    #             ":" + ep_ns_name
    #         ],
    #         visibility = ["//visibility:public"],
    #     )

#     MAIN = """
# (* GENERATED FILE - do not edit *)
# module {alias} = {ep}
#     """.format(
#         alias = wrapper,
#         ep    = mname + "_wrapper"
#     )

#     native.genrule(
#         name = ns_name + ".ml.gen",
#         outs = [ns_name + ".ml"],
#         cmd  = "echo -e '{}' > $@".format(MAIN)
#     )

    ## "wrapper" is just for dune compatibility
    ocaml_module(
        name   = api_name, # ns_name, # + "_wrapper",
        # module_name = ep_mname, #  + "_wrapper",
        # struct = name + "_wrapper.ml",
        struct = api_name + ".ml",
        opts   = OPTS,
        deps   = DEPS + [
            # ":" + name + "_types_wrapper", # Types_generated
            ":" + name + "_CtypesTYPE", # Zstd_CtypesTYPE
            ":" + name + "_functions", # Function_description
            ":" + name + "_CtypesFOREIGN", # Zstd_CtypesFOREIGN
        ],
        visibility = ["//visibility:public"],
    )

    if ep:
        # just for dune compatibility
        ENTRYPT = """
(* GENERATED FILE - do not edit *)
module {ep_mname} = struct
  module Types     = {types}
  module Functions = {fmod}.{fnfunctor}({fns})
end
        """.format(
            ep_mname = ep_mname,
            types=types_module_name, # Types_generated
            tmod = tmod,
            tfunctor = tfunctor,
            typs = mname + "_CtypesTYPE",
            fmod = fmod,        # Function_description
            fnfunctor = fnfunctor, # Functions
            fns = mname + "_CtypesFOREIGN"
        )
    else:
        ENTRYPT = """
(* GENERATED FILE - do not edit *)
module Types     = {tmod}.{tfunctor}({typs})
module Functions = {fmod}.{fnfunctor}({fns})
        """.format(
            types=types_module_name, # Types_generated
            tmod = tmod,
            tfunctor = tfunctor,
            typs = mname + "_CtypesTYPE",
            fmod = fmod,        # Function_description
            fnfunctor = fnfunctor, # Functions
            fns = mname + "_CtypesFOREIGN"
        )

    native.genrule(
        name = api_name + ".ml.gen",
        outs = [ep_ml],   # [ns_name + ".ml"],
        # name = name + "_wrapper.ml.gen",
        # outs = [name + "_wrapper.ml"],
        cmd  = "echo -e '{}' > $@".format(ENTRYPT)
    )

#     ocaml_module(
#         name   = name + "_functions_wrapper",
#         module_name = functions_wrapper_mod,
#         struct = name + "_functions_wrapper.ml",
#         opts   = OPTS,
#         deps   = DEPS + [
#             ":" + name + "_CtypesFOREIGN",
#             ":" + name + "_functions",
#         ],
#         visibility = ["//visibility:public"],
#     )

#     FNSMOD = """
# include {mod}.{fnfunctor}({fnimpl})
#     """.format(mod = fmod, fnfunctor=fnfunctor,
#                fnimpl = mname + "_CtypesFOREIGN")

#     native.genrule(
#         name = name + "_functions_wrapper_gen",
#         outs = [name + "_functions_wrapper.ml"],
#         cmd  = "echo -e '{}' > $@".format(FNSMOD)
#     )

    ## /Generate Ctypes.FOREIGN implementation
    ocaml_module(
        name   = name + "_CtypesFOREIGN",
        module_name = mname + "_CtypesFOREIGN",
        struct = name + "_CtypesFOREIGN.ml",
        opts   = OPTS,
        deps   = DEPS + [
            "@opam.ctypes//lib",
            # ":" + name + "_c_adapter_lib" # w/o optimization
        ],
        cc_deps = [":" + name + "_c_adapter_lib"] # -c opt
    )

    adapter_generator = name + "_adapter_generator"

    native.genrule(
        name = name + "_CtypesFOREIGN.ml.gen",
        outs = [name + "_CtypesFOREIGN.ml"],
        tools = [adapter_generator],
        cmd = "$(execpath {}) ml date_adapter > \"$@\"".format(
            adapter_generator),
    )
    ## /Generate Ctypes.FOREIGN implementation

    ## Generate C adapter lib
    cc_library(
        name = name + "_c_adapter_lib",
        srcs = [name + "_c_adapter.c"],
        linkstatic = True,
        deps  = cclibs + ["@opam.ctypes//lib:hdrs"]
    )

    native.genrule(
        name = name + "_c_adapter_gen",
        outs = [name + "_c_adapter.c"],
        tools = [adapter_generator],
        cmd = "$(execpath {}) c date_adapter > \"$@\"".format(
            adapter_generator)
    )
    ## /Generate C adapter lib

    ocaml_binary(
        name     = adapter_generator,
        prologue = [":" + name + "_types",
                    ":" + name + "_types_wrapper"],
        main     = name + "_funcs_tool",
        opts     = OPTS,
    )

    ocaml_module(
        name   = name + "_funcs_tool",
        struct = name + "_funcs_gen_tool.ml",
        opts   = OPTS,
        deps   = DEPS + [":" + name + "_types",
                         ":" + name + "_functions"]
    )

    ctypes_functions_gen(
        name    = name + "_funcs_gen",
        out     = name + "_funcs_gen_tool.ml",
        hdrs    = cchdrs,
        mod     = fmod,
        functor = fnfunctor
    )

    ocaml_module(
        name   = name + "_functions",
        module_name = fmod,
        opts   = ["-no-alias-deps"],
        struct = fmodfile,
        deps   = [
            ":" + name + "_types_wrapper",
            "@opam.ctypes//lib",
            "@opam.ctypes//stubs/lib"
        ]
    )

    ################  TYPES  ################
    ocaml_module(
        name        = name + "_types_wrapper",
        module_name = types_module_name,
        struct = name + "_types_wrapper.ml",
        opts   = OPTS,
        deps   = DEPS + [":" + name + "_CtypesTYPE",
                         ":" + name + "_types"
                         ],
        visibility = ["//visibility:public"],
    )

    TYPESMOD = """
(* GENERATED FILE - DO NOT EDIT *)
include {mod}.{tfunctor}({impl})
    """.format(mod=tmod, tfunctor=tfunctor,
               impl = mname + "_CtypesTYPE")

    native.genrule(
        name = name + "_types_wrapper_gen",
        outs = [name + "_types_wrapper.ml"],
        cmd  = "echo -e '{}' > $@".format(TYPESMOD)
    )

    # implementation of Ctypes.TYPE
    ocaml_module(
        name   = name + "_CtypesTYPE",
        # module_name = tmod + "_CtypesTYPE",
        struct = name + "_CtypesTYPE.ml",
        opts   = OPTS,
        deps   = ["@opam.ctypes//lib"]
    )

    types_generator_exe = name + "_types_generator_exe"
    native.genrule(
        name = name + "_CtypesTYPE.ml.gen",
        outs = [name + "_CtypesTYPE.ml"],
        tools = [":" + types_generator_exe],
        cmd = "$(execpath :{}) > \"$@\"".format(types_generator_exe),
    )

    cc_binary(
        name = types_generator_exe,
        srcs = [name + "_types_generator.c"],
        deps  = cclibs + ["@opam.ctypes//lib:hdrs"]
    )

    gengen_tool = ":" + name + "_types_generator_generator_bin"
    native.genrule(
        name = name + "_types_generator.c.gen",
        outs = [name + "_types_generator.c"],
        tools = [gengen_tool],
        cmd = "$(execpath {}) > \"$@\"".format(gengen_tool)
    )

    ocaml_binary(
        name     = name + "_types_generator_generator_bin",
        main     = name + "_types_generator_generator",
        vm_linkage = "static",
        opts     = OPTS # + ["-verbose"]
    )

    ocaml_module(
        name   = name + "_types_generator_generator",
        struct = name + "_types_generator_generator.ml",
        opts   = OPTS + ["-no-alias-deps", "-w", "-49"],
        deps   = ["@opam.ctypes//stubs/lib",
                  ":" + name + "_types"]
    )

    ctypes_types_gen(
        name    = name + "_tgen",
        out     = name + "_types_generator_generator.ml",
        hdrs    = cchdrs,
        mod     = tmod,
        functor = tfunctor
    )

    ocaml_module(
        name   = name + "_types",
        module_name = tmod,
        struct = tmodfile,
        deps   = ["@opam.ctypes//lib"],
        visibility = visibility
    )

######################
ctypes_module = macro(
    implementation = _ctypes_module_impl,
    attrs = {
        # name attr == <api_stem>
        "api_name": attr.string(
            doc = "Default: <api_stem>_api",
            configurable=False
        ),
        "wrapper": attr.string(
            doc = "Embedded in <api_name>.ml, uses module aliases to wrap Types and Functions modules. Default: no embedded wrapper.",
            configurable=False
        ),
        "types_module": attr.string(
            doc = "Default: <api_stem>_Types",
            configurable=False
        ),
        "functions_module": attr.string(
            doc = "Default: <api_stem>_Functions",
            configurable=False
        ),
        "functors": attr.label_keyed_string_dict(
            doc = """
Keys: filenames; vals: string name of functor.
First record: types, second: functions
            """,
            configurable = False,
        ),
        "cclibs": attr.label_list(
            default = [],
            configurable=True),
        "cchdrs": attr.string_list(configurable=True),
    },
)

