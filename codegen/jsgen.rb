# This file contains the javascript code generator for mipsgen.
#
# See scripts/mipsgen.rb for the caller of this code.
# See disasm/js/mipsdis.js for the disassembler that hosts the generated code.
# See docs/jsgen.md for more info.

# The argument list for calling javascript decode_xxx functions.
$jsargs = "pc, op";

def js_generate_comment_header
puts <<HERE
/*
 * This file contains autogenerated routines for dispatching and disassembling
 * MIPS opcodes.
 *
 * The code has been generated by mipsgen.
 *
 * See scripts/mipsgen.rb for the code generator framework.
 * See codegen/jsgen.rb for javascript specific information.
 */

HERE
end

# Builds the format string used by snprintf in the generated decoder function.
# See tables/asm_format.txt.
# See tables/field_format.txt.
def js_build_format_string(mne, tokens, field_format)
    fmt_a = []

    tokens.each{|t|
        if (field_format.include?(t))
            fmt_a << field_format[t][0]
        else
            fmt_a << t
        end
    }

    fmt_s = mne

    if (!fmt_a.empty?)
        fmt_s += ' ' + fmt_a.join
    end

    return '"' + fmt_s + '"'
end

# Builds the arguments for the format string built by js_build_format_string.
def js_build_args(mne, tokens, field_format)
    args_a = []

    tokens.each{|t|

        if (field_format.include?(t))
            pc = field_format[t][1]
            field_args = pc ? "pc,op" : "op"
            args_a << "get#{t}(#{field_args})"
        end
    }

    return args_a
end

# Builds the error checks required for a decoder.
# Every opcode has its bitmask checked against a comparison value.
# Some opcodes (cl, jalr) require extra checking.
# See tables/opcode_bits.txt.
def js_build_error_checks(mne, bitmasks)
    mask = bitmasks[mne]['mask']
    value = bitmasks[mne]['value']
    has_reserved = bitmasks[mne]['reserved']

    checks = []

    if (has_reserved)
        checks << "check_opcode(op, #{mask}, #{value})"
    end

    if (mne =~ /^cl/)
        checks << 'check_cl(getrt(op), getrd(op))'
    end

    if (mne =~ /^jalr/)
        checks << "check_jalr(getrs(op), getrd(op))"
    end

    return checks
end

# Emits the generated decoder to stdout.
def js_emit_decoder(mne, checks, fmt, args)
    spargs = [fmt] + args

    puts "function decode_#{mne}(#{$jsargs})"
    puts "{"

    if (!checks.empty?)
    puts "    ok = #{checks.join(' && ')};"
    puts "    if (!ok) return 'illegal';"
    puts ""
    end

    puts "    return sprintf(#{spargs.join(', ')});"
    puts "}"
    puts ""
end

# Generate all decoders.
def js_generate_decoders(asm_format, field_format, bitmasks)
    asm_format.each{|k,toks|

        fmt = js_build_format_string(k, toks, field_format)
        args = js_build_args(k, toks, field_format)
        checks = js_build_error_checks(k, bitmasks)
  
        js_emit_decoder(k, checks, fmt, args)
    }
end

# Generate a dispatcher function by generating a switch statement that calls
# the correct decoding routines.
#
# See tables/dispatch_tables.txt.
def js_gen_dispatcher(name, field, groups)
    puts "function decode_#{name}(#{$jsargs})"
    puts "{"
    puts "    switch (get#{field}(op))"
    puts "    {"

    groups.each{|grp,vals|
        vals.each{|v|
    puts "        case #{v}:"
        }
    puts "            return decode_#{grp}(#{$jsargs});"
    puts "            break;"
        }

    puts "    }"
    puts "}"
    puts ""
end

# Generate all the dispatcher functions.
def js_generate_dispatchers(tables)
    tables.each{|k, v|
        js_gen_dispatcher(k, v['field'], v['groups'])
    }
end

# Generate all the code necessary for the javascript version disassembler.
def js_generate(gen_info)

    asm_format = gen_info['asm_format']
    field_format = gen_info['field_format']
    bitmasks = gen_info['bitmasks']
    tables = gen_info['dispatch_tables']

    js_generate_comment_header()
    js_generate_decoders(asm_format, field_format, bitmasks)
    js_generate_dispatchers(tables)
end
