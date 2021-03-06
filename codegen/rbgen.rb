# This file contains the ruby code generator for mipsgen.
#
# See scripts/mipsgen.rb for the caller of this code.
# See disasm/js/mipsdis.js for the disassembler that hosts the generated code.
# See docs/rbgen.md for more info.

# The argument list for calling ruby decode_xxx functions.
$rbargs = "pc, op";

def rb_generate_comment_header
puts <<HERE
# This file contains autogenerated routines for dispatching and disassembling
# MIPS opcodes.
#
# The code has been generated by mipsgen.
#
# See scripts/mipsgen.rb for the code generator framework.
# See codegen/rbgen.rb for ruby specific information.

HERE
end

# Builds the format string used by snprintf in the generated decoder function.
# The metadata for this is in tables/asm_format.txt and tables/field_format.txt.
def rb_build_format_string(mne, tokens, field_format)
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

# Builds the arguments for the format string built by rb_build_format_string.
def rb_build_args(mne, tokens, field_format)
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
# The metadata for this is in tables/opcode_bits.txt
def rb_build_error_checks(mne, bitmasks)
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
def rb_emit_decoder(mne, checks, fmt, args)
    spargs = [fmt] + args

    puts "def decode_#{mne}(#{$rbargs})"

    if (!checks.empty?)
    puts "    if (!(#{checks.join("&&")}))"
    puts "        return 'illegal'"
    puts "    end"
    puts ""
    end

    puts "    return sprintf(#{spargs.join(',')})"
    puts "end"
    puts ""
end

# Generates all decoders.
def rb_generate_decoders(asm_format, field_format, bitmasks)
    asm_format.each{|k,toks|
        fmt = rb_build_format_string(k, toks, field_format)
        args = rb_build_args(k, toks, field_format)
        checks = rb_build_error_checks(k, bitmasks)
        rb_emit_decoder(k, checks, fmt, args)
    }
end

# Generates a dispatch function.
def rb_gen_switch(name, field, groups)
    puts "def decode_#{name}(#{$rbargs})"
    puts "    case (get#{field}(op))"

    groups.each{|grp,vals|
    puts "        when #{vals.join(',')}"
    puts "            return decode_#{grp}(#{$rbargs});"
        }

    puts "    end"
    puts "end"
    puts ""
end

# Generates all dispatch functions.
def rb_generate_switches(tables)
    tables.each{|k, v|
        rb_gen_switch(k, v['field'], v['groups'])
    }
end

# Entry point for ruby code generation.
def rb_generate(gen_info)
    asm_format = gen_info['asm_format']
    field_format = gen_info['field_format']
    bitmasks = gen_info['bitmasks']
    tables = gen_info['dispatch_tables']

    rb_generate_comment_header()
    rb_generate_decoders(asm_format, field_format, bitmasks)
    rb_generate_switches(tables)
end
