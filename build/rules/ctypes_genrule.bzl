## We need these two rules in order to support configurable
## cclibs and cchdrs.

##############################
def _ctypes_functions_gen_impl(ctx):

    HDR = """
(* GENERATED FILE - do not edit *)
let () =
  let concurrency = Cstubs.unlocked in
  let errno = Cstubs.ignore_errno in
  let prefix = Sys.argv.(2) in
  match Sys.argv.(1) with
  | "ml" ->
    Cstubs.write_ml ~concurrency Format.std_formatter ~prefix
      ~errno
      (module {mod}.{functor})
  | "c" ->
    """.format(mod=ctx.attr.mod, functor = ctx.attr.functor)

    hdrlines = []
    for hdr in ctx.attr.hdrs:
        if hdr.startswith("<"):
            # hdrs.append(hdr)
            hdrlines.append('print_endline {{|#include {}|}};'.format(
                hdr))
        else:
            # hdrs.append('"' + hdr + '"')
            hdrlines.append(
                'print_endline {{|#include "{}"|}};'.format(
                    hdr))

    INCLUDES = "\n".join(hdrlines)

    BODY = """
    Cstubs.write_c ~concurrency Format.std_formatter ~prefix
      ~errno
      (module {mod}.{functor})
  | s -> failwith ("unknown functions "^s)
    """.format(mod=ctx.attr.mod, functor = ctx.attr.functor)

    ctx.actions.write(
        output  = ctx.outputs.out,
        content = HDR + INCLUDES + BODY,
        is_executable = False
    )

    return DefaultInfo(
        files = depset(
            direct = [ctx.outputs.out],
        )
    )

######################
ctypes_functions_gen = rule(
    implementation = _ctypes_functions_gen_impl,
    attrs = dict(
        out     = attr.output(mandatory = True),
        hdrs    = attr.string_list(mandatory = True),
        mod     = attr.string(),
        functor = attr.string()
    )
)

################################################################
def _ctypes_types_gen_impl(ctx):

    HDR = """
(* GENERATED FILE - do not edit *)
let () =
  """
    hdrlines = []
    for hdr in ctx.attr.hdrs:
        if hdr.startswith("<"):
            # hdrs.append(hdr)
            hdrlines.append('print_endline {{|#include {}|}};'.format(
                hdr))
        else:
            # hdrs.append('"' + hdr + '"')
            hdrlines.append(
                'print_endline {{|#include "{}"|}};'.format(
                    hdr))

    INCLUDES = "\n".join(hdrlines)

    BODY = """
  Cstubs_structs.write_c Format.std_formatter
  (module {mod}.{functor})
    """.format(mod=ctx.attr.mod, functor = ctx.attr.functor)

    ctx.actions.write(
        output  = ctx.outputs.out,
        content = HDR + INCLUDES + BODY,
        is_executable = False
    )

    return DefaultInfo(
        files = depset(
            direct = [ctx.outputs.out],
        )
    )

######################
ctypes_types_gen = rule(
    implementation = _ctypes_types_gen_impl,
    attrs = dict(
        out     = attr.output(mandatory = True),
        hdrs    = attr.string_list(mandatory = True),
        mod     = attr.string(),
        functor = attr.string()
    )
)
